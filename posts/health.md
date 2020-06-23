<p>Health probes are essential to running a highly available service, yet they are surprisingly <strong>tricky to implement without inadvertently making your uptime <em>worse</em></strong>. Even popular frameworks like Spring Boot (until recently<sup id="spring-defaults"><a href="#spring-defaults-note">1</a></sup>) used unfortunate defaults that may accidentally encourage a hurried developer to fall into some surprising traps that reduce their services' uptime.</p>

<p>Over time, my team has come up with a <strong>set of rules to avoid these traps</strong>. I'll lay them out first succinctly, and then explain them in detail along with the model we use that embodies them.</p>

<ol>
  <li>Don't overload health endpoints – favor more over reuse</li>
  <li>Keep logic out of monitors – put in endpoints</li>
  <li>Be very conservative when determining if <strong>un</strong>healthy</li>
  <li>Run health checks in background – not on demand</li>
</ol>

<p><strong>If your in a hurry</strong>, you can <a href="#summary"><strong>skip straight to the summary</strong></a>.</p>

<aside>This blog may use Kubernetes terms like "container" and "probe", but these ideas can be applied to services running on any compute platform. For a quick overview of Kubernetes terms, see my short post <a href="//2017/06/Kubernetes-distilled.html" rel="noreferrer noopener" target="_blank">Kubernetes Distilled</a>.</aside>

<h2>A narrow, useful model of health</h2>

<p>In any nontrivial service, health is really a multi-dimensional spectrum. A service degrades in immeasurable ways, and is probably degraded in several of them right now as you read this! This is why <a href="https://landing.google.com/sre/sre-book/chapters/service-level-objectives/" rel="noreferrer noopener" target="_blank">service level objectives</a> (SLOs) are so useful. They distill the chaos into relatively few user experience objectives, and user experience is ultimately what matters.</p>

<p>However, many times we still need to make a point in time, yes-or-no decision that can't be a complex aggregation of metrics like SLOs typically require<sup id="metrics-monitor"><a href="#metrics-monitor-note">2</a></sup>. In these cases, like load balancer health checks or Kubernetes probes, we can focus instead on answering more specific questions <em>about</em> health. That is, we can use a useful <a href="https://youtu.be/dnUFEg68ESM?t=1880" rel="noreferrer noopener" target="_blank">model</a> of health instead of a realistic one.</p>

<p>This model consists of the following <strong>5 kinds of health resources</strong> (or "queries", or "remote procedures", or "endpoints") your service should provide for use by clients like Kubernetes, monitoring software, load balancers, yourself, peer services, etc.:</p>

<dl>
  <dt>Readiness</dt>
  <dd>Is this server warmed up, fully loaded, and "ready" to serve traffic?</dd>
  
  <dt>Liveness</dt>
  <dd>Does this server need to be killed and recreated?</dd>
  
  <dt>Health</dt>
  <dd>Is this server able to serve ANY significant traffic successfully?</dd>
  
  <dt>Diagnostics</dt>
  <dd>What's the full state of the server's ability to serve requests and its dependencies' health?</dd>
  
  <dt>Smoketests</dt>
  <dd>How do some significant use cases work from a particular call site?</dd>
</dl>

<p>To answer most of these questions, we take a <a href="https://landing.google.com/sre/sre-book/chapters/monitoring-distributed-systems/#black-box-versus-white-box-q8sJuw" rel="noreferrer noopener" target="_blank">white-box</a> approach, using explicitly defined <var>checks</var> which either pass or fail. This means we have to think about how our process works, and some of the known ways that it can degrade. We will need to note external dependencies in particular, both because we rely on them so heavily (e.g. your database), and because using them relies on a network, which is orders of magnitude less reliable than a syscall or interprocess call on the same machine.</p>

<h3>Health checks</h3>

<p>The checks that compose the resources can be differentiated in three dimensions:</p>

<ol>
    <li>The criticality of the dependency it is checking</li>
    <li>The depth of health we will check</li>
    <li>The timing of the check</li>
</ol>

<h4>Criticality</h4>

<p>The impact of a fault in a dependency depends on how critical the dependency is to our service's value. If the dependency is critical, then without it we know to take some kind of action (like serve an error page, or route to another data center). For this reason we break criticality down into two flavors:</p>

<dl>
  <dt>Hard dependencies</dt>
  <dd>Think: your database. Dependencies which are in at least some way <em>essential</em> for the <em>entirety</em> of your service's function. Without just one of these dependencies, your service is <em>worthless</em>. It might as well be completely down, and taking it down is likely preferable to even trying to do any work without one of these dependencies functioning in the ways you need it. If it's required for some requests but not others, and you care about those "others", then it's not a hard dependency.</dd>
  
  <dt>Soft dependencies</dt>
  <dd>Dependencies which are <em>non-essential</em>. They may still be important, but you can at least do <em>something</em>–provide <em>some</em> value–without these. A full outage would still be worse than losing one of these.</dd>
</dl>

<aside>Health checks aside, strive to make all dependencies <em>soft</em> dependencies. Your uptime is capped by your <em>hard</em> dependencies. If every request <em>requires</em> your database, and it is up 99.9% of the time, no amount of cleverness on yor part will make your service's uptime any better than 99.9%. If every request requires two external dependencies, both with 99.9% uptime, the effect is multiplicative: you will never beat 99.8% uptime. Refactoring towards soft dependencies is easier said than done, but this may involve simplifying your architecture, caching responses, using fallbacks, moving some work to be done asynchronously, etc. Topics for another day however.</aside>

<h4>Depth</h4>

<p>The depth of a check is how coupled the check is to the useful functionality of the dependency. There are two broad classes of health <var>depths</var> we may check:</p>

<dl>
  <dt>Connectivity (low depth)</dt>
  <dd>Do not check very far; only that your process can at least <em>communicate</em> (including TLS handshake and authentication) with this dependency. It is a property of the network, your application configuration, the dependency's configuration, and its basic availability. Example: you can establish a connection to your database, but we don't know if the database is serving queries as expected.</dd>
  
  <dt>Transitive health (high depth)</dt>
  <dd>This is the health of the dependency itself: can it serve traffic from your service successfully? It is a property of both connectivity and how well the dependency is functioning. Example: a test database query quickly returns expected results.</dd>
</dl>

<p>You may be able to connect to a dependency, even if it is not transitively healthy. This means transitive health of a dependency will always be equally or less available than its connectivity. Given we must be conservative about <em>un</em>health, sometimes we only want to concern ourselves with connectivity. We'll see how this plays out below.</p>

<h4>Timing</h4>

<p>The last dimension is about when the check is run. We start with two broad categories:</p>

<dl>
  <dt>Synchronous</dt>
  <dd>A synchronous check is run when the endpoint is queried, blocking until a result is determined.</dd>

  <dt>Asynchronous</dt>
  <dd>Asynchronous checks are run in the background, and endpoints serve the last seen result immediately.</dd>
</dl>

<p>One of our rules was to run health checks in the background (asynchronously). If your load balancers are scaled out much further than your service, all those load balancer health checks start to add up to quite a bit of traffic. This can quickly escalate to hammering your service and dependencies with health checks. Asynchronous checks combat this problem by decoupling the timing of the check from the timing of the query: health requests return immediately, serving cached results from the last time the checks actually ran. If you have more service than load balancer replicas, you may benefit from keeping them synchronous. A hybrid approach–use a cached result while valid, otherwise check synchronously–also works well.</p>

<aside>At one point, out of paranoia, we had some rather expensive health checks. Additionally, we used a shared load balancing layer which of course was heavily replicated. As a result, health checks ended up constituting a <em>majority</em> of our service load.</aside>

<h2>Implementing health endpoints</h2>

<p>Armed with this model of health checks, we go back and use it to describe the how and why behind our 5 health resources.</p>

<p>Recall the first rule is not to overload them. Don't use the same URL or RPC for readiness and liveness, or readiness and health, etc. Trying to cleverly reuse resources couples these distinct checks together. For what? Adding additional resources is trivial to do in most frameworks. Instead, optimize each for their singular intended purpose, giving each their own procedure that may be invoked separately. This better protects against traps that may hurt your users, and allows the logic of each to grow with your service without having to also reconfigure load balancers or monitors at the same time.</p>

<p>With that separation of concerns, we are also poised to follow the second rule: put logic in endpoints and out of clients. Rather than scripting complex rules or logic or behavior ("do X, then Z, if response looks like this, or this, or this, then treat as healthy, ...") inside generic tools like monitors, put the rules and behavior inside your <em>code</em>–the logic of procedures themselves. This makes the endpoints more reusable, particularly where tools are difficult or impossible (or cost $) to customize or script. Even if your fancy expensive load balancer can be scripted, coupling to those features makes it harder to be use a different load balancer tech later.</p>

<aside>Do not consider all of the details essential, this is mostly about principles. Ideally, a library would take care of the details–some are quite complex to implement without introducing their own bugs–and in fact this is what we do at Red Hat.</aside>

<h3>Readiness</h3>

<p>Readiness is a query particularly for Kubernetes controlled starts of containers. Rather than throwing traffic at the container immediately, it waits until it is <em>ready</em>.</p>

<ul>
  <li><strong>DO</strong> return OK once the process is "warmed up." You can wait for lazy loading, run some smoke tests to JIT compile hot code paths, warm in memory caches, wait until <em>hard</em> dependency <em>connectivity</em> is established, and so on. This helps prevent long tail latencies after startup, and protects against a bad configuration taking down your service, respectively.</li>
  <li><strong>CONSIDER</strong> performing no checks, and always returning OK, once you have first returned OK. If you're using global load balancing, we have a different resource for taking a region out of rotation.</li>
  <li><strong>DO NOT</strong> check soft dependencies. This means the container may still be considered ready without them, even if the problem is misconfiguration on your end. Unfortunate, but you should allow Kubernetes to reschedule your pod at any time, and this will require your containers' readiness checks to pass. If you try to check soft dependencies, even just connectivity, you risk blocking start up for your entire service if one is down. Losing a soft dependency, as discussed above, is not fatal, but a full outage sure is. We'd like to catch misconfigurations on our end, but unfortunately it's difficult, if not <a href="https://www.google.com/search?q=%22unreliable+failure+detectors+for+reliable+distributed+systems%22" target="_blank" rel="noreferrer noopener">impossible</a>, to detect whether the failure is due to our configuration, a specific Kubernetes node, or external factors.</li>
</ul>

<h3>Liveness</h3>

<p>Liveness is a container self-healing mechanism. If a container is not alive, Kubernetes will restart it. Crucially, this means the scope of liveness is the container and only the container.</p>

<ul>
  <li><strong>DO</strong> return NOT OK for illegal states local to the container or process: threads are deadlocked, memory is leaking/out, [container] disk is full, etc. These may all be cured be recreating the container.</li>
  <li><strong>DO NOT</strong> check <em>any</em> dependencies. A restart will not help you if your database is down, and such an outage would result in <em>all</em> of your containers restarting, which might make the problem worse, or cause new problems.</li>
</ul>

<aside>It is tempting to check hard dependencies, even just connectivity. How many times has a server restart helped recover your service's connectivity to a database? Wouldn't it be nice if Kubernetes took care of the turn-it-off-and-on-again problems? It would, but if you're running at a large enough scale, the risks may outweight the benefits here. Ideally your client code is able to handle reconnecting on its own, for example, without a restart.</aside>

<h3>Health</h3>

<p>The plain "health" resource is used by global load balancers, peer services, and uptime monitors. A repeat, unhealthy (or timed out) response indicates the server is unable to serve any valuable requests. For a load balancer, this means it should not route requests to that server (which may be a virtual server representing, say, an entire region). For a peer service, it means the peer may be unhealthy itself (if this is used as a transitive health check). For an uptime monitor, it may alert someone, or track statistics for later reporting.</p>

<ul>
  <li><strong>DO</strong> return NOT OK if any <em>hard</em> dependencies have failed <em>transitive health</em> checks.</li>
  <li>If there are no hard dependencies, it is perfectly fine and often correct to simply do nothing and always return OK, indicating the service is likely at least running, resolvable, and reachable through the network.</li>
  <li><strong>DO NOT</strong> check any <em>soft</em> dependencies. It may be tempting, but any check that relies on a globally shared failure domain may then take all regions out of rotation; in other words, no requests served instead of some requests served. This is why you must be conservative when deciding a service is <em>un</em>healthy.</li>
  <li><strong>DO</strong> use the health endpoint for a basic uptime monitor and alert.</li>
</ul>

<aside>This was also learned the hard way. A critical internal service of ours health-checked based on its basic functionality. When it failed due to the outage of a dependency, the service went completely down. Unfortunately, there were other, more common code paths that would've kept working for most users... if we had only kept the nodes in rotation!</aside>

<h3>Diagnostics</h3>

<p>So far, we've looked at three resources which are surprisingly restricted, and may not really examine all that much. What if you want to look at the bigger picture: all of your dependencies, perhaps even some application configuration? Or, maybe you want to look at the state of a particular soft dependency?</p>

<p>Diagnostics fulfills this niche. Whereas the previous resources need only return an indication of pass or fail, diagnostics is just as much about rich content, intended for human operators. For example, if you monitoring shows some averse symptoms, or when testing out a new environment, you may take a quick peak at your diagnostics endpoint to see if any dependency checks are failing. You may also use it to automatically alert on known causes. For example, you could set up some alert policies for some of the soft dependencies that aren't as urgent as your SLO-based alerts (see also: <a href="https://landing.google.com/sre/sre-book/chapters/monitoring-distributed-systems/#symptoms-versus-causes-g0sEi4" rel="noreferrer noopener" target="_blank">Symptoms Versus Causes</a>).</p>

<ul>
  <li><strong>DO</strong> include as much content as you'd like (such as all dependencies' health and connectivity) that is generally useful to operators.</li>
  <li><strong>DO</strong> authorize access to these details, which may be sensitive.</li>
  <li><strong>DO NOT</strong> include any secrets in content.</li>
  <li><strong>CONSIDER</strong> a parameter which allows filtering down to specific checks or set of checks.</li>
  <li><strong>CONSIDER</strong> alerting on diagnostics.</li>
</ul>

<h3>Smoketests</h3>

<p>Lastly, we have smoketests, which warrant some special attention. I'm not just talking about making "smoketest" calls to your service. I'm talking about <strong>a specific endpoint that itself does smoketesting for you</strong>.</p>

<p>I use these sparingly, as I much prefer monitoring the service levels of actual users, rather than synthetic calls. However, because service levels rely on actual traffic, there are two cases where service level monitoring falls short. If you alert on a 10% error rate over 5 minutes, but you only have 50 calls in that time, it just takes 5 failed calls in 5 minutes to trip your alarm. Adding in traffic from synthetic calls helps improve your signal-to-noise ratio. Additionally, sometimes you need to monitor something that isn't available for use by actual users, such as a new region or version. When you have no traffic to look at at all, you need to generate some. Thats where these calls come in handy.</p>
  
<p>Now perhaps you can craft a call using only your terminal and jaunty hacker wits, but <strong>wouldn't it be easier if all you had to remember was <code>/smoketest</code></strong>? Likewise, it makes monitors like New Relic Synthetics easier (and cheaper!) to set up to continuously generate such traffic because all you need is a simple ping check instead of scripts. We can also easily filter out test traffic from our access logs or metrics. Because our code knows it's running tests, it is poised to deal with pesky side effects that happen from normal calls, such as by inserting test data that gets cleaned up in the background, sending email to a test inbox, charging a fake credit card, etc. It even helps secure our API: instead of opening up actual calls to our monitoring tools (which may have widely accessible credential storage), we can restrict it to the health endpoints. This all falls right in line with our principle of keeping logic in endpoints and out of monitors. It's cohesive, and codifies domain and operational knowledge.</p>

<p>Finally, running such smoketests a few times at startup may be a simple and pragmatic way to warm up your server process (JIT, caches, connections, etc) for readiness.</p>

<ul>
  <li><strong>DO</strong> add tests for high value use cases.</li>
  <li><strong>DO NOT</strong> try to be thorough. It's a lost cause. That's what service level monitoring is for.</li>
  <li><strong>DO</strong> authorize calls separately from the rest of your API.</li>
  <li><strong>CONSIDER</strong> running checks asynchronously if you cannot adequately authorize calls.</li>
  <li><strong>CONSIDER</strong> a parameter which allows filtering to specific checks or set of checks.</li>
  <li><strong>CONSIDER</strong> alerting off of smoketests.</li>
</ul>

<h2 id="summary">Summary</h2>

<p>We discussed four high level guidelines:</p>

<ol>
  <li>Don't overload health endpoints – favor more over reuse</li>
  <li>Keep logic out of monitors – put in endpoints</li>
  <li>Be very conservative when determining if <strong>un</strong>healthy</li>
  <li>Run health checks in background – not on demand</li>
</ol>

<p>Then we described a model of health based on 5 resources defined by explicit, cause-oriented checks. These checks vary on the <strong>criticality</strong> of the dependency, the <strong>depth</strong> of health checked, and the <strong>timing</strong> of the check. The health resources are summarized in the table below.</p>

<table class="health-resources">
  <caption>Summary of health resources.</caption>
  <thead>
    <th scope="row">Resource</th>
    <th scope="col">Readiness</th>
    <th scope="col">Liveness</th>
    <th scope="col">Health</th>
    <th scope="col">Diagnostics</th>
    <th scope="col">Smoketests</th>
  </thead>
  <tbody>
    <tr>
      <th scope="row">Purpose</th>
      <td>Is the server done loading?</td>
      <td>Should the server be restarted?</td>
      <td>Is the server able to serve some traffic?</td>
      <td>What's the status of everything?</td>
      <td>How are real use cases working for known callers?</td>
    </tr>
    <tr>
      <th scope="col" colspan="6">Intended user</th>
    </tr>
    <tr>
      <th scope="row">Kubernetes</th>
      <td>✔</td>
      <td>✔</td>
      <td></td>
      <td></td>
      <td></td>
    </tr>
    <tr>
      <th scope="row">Operators</th>
      <td></td>
      <td></td>
      <td>✔</td>
      <td>✔</td>
      <td>✔</td>
    </tr>
    <tr>
      <th scope="row">Peer services</th>
      <td></td>
      <td></td>
      <td>✔</td>
      <td>✔</td>
      <td></td>
    </tr>
    <tr>
      <th scope="row">Monitors</th>
      <td></td>
      <td></td>
      <td>✔</td>
      <td>✔</td>
      <td>✔</td>
    </tr>
    <tr>
      <th scope="row">Load balancers</th>
      <td></td>
      <td></td>
      <td>✔</td>
      <td></td>
      <td></td>
    </tr>
    <tr>
      <th scope="col" colspan="6">Checks</th>
    </tr>
    <tr>
      <th scope="row">Hard dependencies</th>
      <td>Connectivity</td>
      <td></td>
      <td>Health</td>
      <td>Health</td>
      <td></td>
    </tr>
    <tr>
      <th scope="row">Soft dependencies</th>
      <td></td>
      <td></td>
      <td></td>
      <td>Health</td>
      <td></td>
    </tr>
    <tr>
      <th scope="row">Other</th>
      <td>"Warmed up" (caches warmed, lazy loading done, hot code paths run (JIT), ...)</td>
      <td>Illegal states local to the container (OOM, deadlocked threads, ...)</td>
      <td></td>
      <td>Anything you find helpful!</td>
      <td>Real use cases with test data / controlled side effects</td>
    </tr>
  </tbody>
</table>

<p>If you found this helpful, or have questions or concerns, let me know in the comments. Thanks for reading!</p>

<p><small id="spring-defaults-note"><a href="#spring-defaults"><sup>1</sup></a> Actuator includes all health checks in its health endpoint, which I've seen many developers use as a quick health check for load balancers or for Kubernetes probes, even though semantically it matches the <var>diagnostics</var> query described above, which is not appropriate for either. Recently Actuator gained <a href="https://docs.spring.io/spring-boot/docs/current/reference/html/production-ready-features.html#production-ready-Kubernetes-probes-external-state" rel="noreferrer noopener" target="_blank">explicit Kubernetes probe support</a> which has better default behavior.</small></p>

<p><small id="metrics-monitor-note"><a href="#metrics-monitor"><sup>2</sup></a> You probably could conceive of a check which actually relied on, say, pre-aggregated metrics based on black-box, observed symptoms. This would be appropriate for weighted load balancing, and in fact <a href="https://github.com/Netflix/ribbon/wiki/Working-with-load-balancers#weightedresponsetimerule" rel="noreferrer noopener" target="_blank">some load balancers</a> do just that using in memory statistics from previous requests to each member. For layer 7 load balancers, this is not a bad approach, as they are seeing all of the traffic anyway, and monitoring actual calls captures much more subtlty than a binary up/down decision. That said, the two approaches are not mutually exclusive.</small></p>
