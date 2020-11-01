<meta name="id" content="7799320222051028141">
<meta name="labels" content="testing,object oriented programming,java,microservices,domain-driven design">
<meta name="title" content="The secret world of testing without mocking: domain-driven design, fakes, and other patterns to simplify testing in a microservice architecture">
<meta name="description" content="How to simplify microservice testing through a few simple 
applications of domain-driven design and in-memory test doubles (fakes).">

Much has been said about mocks, the controversial, Swiss army knife of test doubles: 

* Don't use them too much [(source)][don't-mock-everything] [(source)][don't-overuse-mocks]
* Know when to verify state or when to verify interactions [(source)][verify-state-or-interactions]
* Don't test implementation detail [(source)][change-detector] 
* Don't mock types you don't own [(source)][don't-mock-third-party-types]
* Only mock classes when dealing with legacy code [(source)][mock-classes]
* Don't mock complex interfaces [(source)][service-call-contracts] [(source)][mocks-are-stupid]

...the list goes on. Much of this comes from mock library authors themselves. For a tool so easy to 
misuse, we're using it quite a lot. Mockito is [one of the most depended-upon Java libraries in the 
world][mockito-popularity].

// While "mocking" is an abstract concept, for the remainder of this post I'll use the term mock to
refer specifically to a mock or stub configured by way of a mocking library like Mockito. Likewise,
when I refer to Mockito, I really mean any mocking library; Mockito just stands out because it has
a welcoming API and is–no doubt as a consequence–measurably very popular.

I was there too, once a frequent Mockito user, perhaps like you are now. Over time however, as my 
application architectures improved, as I began to introduce [real domain 
models][anemic-architecture-testing], the tests I wrote were becoming simpler, easier to add, and 
services easier to develop. Tricky testing problems that loomed over my head for years now had 
obvious solutions. Much to my surprise, I was barely using Mockito at all.

**In this post, I demonstrate some compelling and, in my experience, overlooked advantages to mock 
alternatives.** We will explore the origins of mocking, why mocking may have become so ubiquitous, a 
world without mocking, and the system of incentives, practices, and abstractions that evolve as a 
result. Whether you are a casual or devout mock-ist, I encourage you to keep calm, open your mind, 
and try going without for a while. This post will guide you. You may be surprised what you find.

[don't-mock-everything]: https://github.com/mockito/mockito/wiki/How-to-write-good-tests#dont-mock-everything-its-an-anti-pattern
[verify-state-or-interactions]: https://testing.googleblog.com/2013/03/testing-on-toilet-testing-state-vs.html
[change-detector]: https://testing.googleblog.com/2015/01/testing-on-toilet-change-detector-tests.html
[don't-mock-third-party-types]: https://github.com/mockito/mockito/wiki/How-to-write-good-tests#dont-mock-a-type-you-dont-own
[mockito-popularity]: https://github.com/mockito/mockito/wiki/Mockito-Popularity-and-User-Base
[anemic-architecture-testing]: http://qala.io/blog/anaemic-architecture-enemy-of-testing.html
[mock-classes]: https://javadoc.io/doc/org.mockito/mockito-core/latest/org/mockito/Mockito.html#spy

## The hidden burdens of mocking

We forget because the APIs are so nice, but **mocking is fascinatingly complex under the hood.** 
It's {metaprogramming}: code that implements types at runtime rather than using native language 
features to implement types at compile time.

Mockito's API optimizes for immediate convenience–justifiably so–but **it's this immediate 
convenience that dominates our thinking.** While less sexy, a compile-time implementation has its 
own conveniences. Unfortunately, they are easily overlooked because they take just a little time and
investment in the short term before you can see them. By first reviewing some mocking pitfalls, 
we'll start to see how taking the time to write a class can pay off.

// Most times, we don't see the complexity required to implement runtime metaprogramming as a 
// tradeoff, thanks to Mockito's well-designed abstractions. But occasionally, those abstractions 
// leak. Once, a colleague and I spent a while banging our heads against build failures for just one 
// particular service when we moved our Jenkins server inside a container in an OpenShift 
// environment. This was the error:
//
// ```
// Caused by: java.io.IOException: well-known file /tmp/.java_pid735 is not secure: file's group should be the current group (which is 0) but the group is 1000330000
// ```
// 
// Obvious, right? 😅 It turned out, if you want to accomplish some particularly scandalous tasks 
// like mocking final classes, Mockito attaches a Java agent *at runtime.* Because the current 
// user's group ID didn't match the Java process's group ID, which is due to how user security 
// inside a container works, the process was not allowed to attach an agent to itself.

When a class under test has a mocked dependency, the dependency must be stubbed according to the 
needs of your test. We only stub the methods our class needs for the test, and only for the 
arguments we expect the class to use.

However, by leaving out stubbing some methods, we imply we know _what_ methods are used. By only 
stubbing for certain arguments, we imply we know _how_ those methods are used. If our implementation
changes, [we may need to update our tests][don't-overuse-mocks], even though the behavior hasn't 
changed. Likewise, each time we write a new test, we must recall how the dependency is _used_, so we
stub it the right way.

```java
// A hypothetical anti-corruption layer encapsulating credit.
// Please forgive the very naive domain model.
interface CreditService {
  CreditStatus checkCredit(AccountId account);
  void charge(AccountId account, Money money);
}

// A hypothetical domain service which depends on a CreditService
class OrderProcessor {
  final CreditService creditService;
  // snip...
  
  void processOrder(AccountId account, Order order) {
    if (HOLD.equals(creditService.checkCredit(account))) {
      throw new CreditHoldException(account, order);
    }
    // snip...
  }
}

class OrderProcessorTest {
  // snip...

  @Test
  void throwsIfAccountOnCreditHold() {
      // This works with the current implementation, but what if our implementation 
      // instead changes to just call `charge` instead of first calling `checkCredit`, 
      // relying on the fact that `charge` will throw an exception in this case? The 
      // test will start failing, but actually there is no problem in the production 
      // code. This test is coupled to implementation detail.
      when(creditService.checkCredit(AccountId.of(1))).thenReturn(HOLD);
      assertThrows(
          CreditHoldException.class, 
          () -> orderService.processOrder(account1, testOrder));
  }
}
```

// Please note the domain model in this blog post is ... not great. A good model incorporates 
substantial business expertise, and I am no order processing expert. Nor should anyone really be
[writing their own order processing model in this day and 
age](https://twitter.com/patio11/status/1321851664551145472?s=20).

Additionally, as the dependency itself changes, any tests stubbing it may need to update to conform 
to its updated contract, or our tests may no longer be valid. For example, if an interface 
encapsulates some state between subsequent method calls, or a method has some preconditions or 
postconditions, and [your stub does not reimplement these correctly][mocks-are-stupid], your tests 
may pass even though the application will have a bug in production.

To remove some of this repetition while still using mocks, we can refactor the test setup to be done
once in a `@BeforeEach` method for the whole class. You can even go one step further and pull out 
the stubbing into a static method, which can be reused in multiple test classes.

```java
class Mocks {
  // A factory method for a mock that we can reuse in many test classes.
  // Note the state of the stub is obscured from our tests, hurting 
  // readability.
  static CreditService creditService() {
    var creditService = mock(CreditService.class);
    when(creditService.checkCredit(AccountId.of(1))).thenReturn(HOLD);
    doThrow(NotEnoughCreditException.class)
        .when(creditService).charge(AccountId.of(1), any(Money.class));
    return creditService;
  }
}
```

There is another way to make an implementation of a type reusable so that you don't have to 
constantly reimplement it: the familiar, tool-assisted, keyword-supported, fit-for-purpose class. 
Classes are built-in to the language to solve precisely this problem of capturing and codifying 
knowledge for reuse in a stateful type. Write it once, and it sticks around to help you with the 
next test. **Not only do classes elegantly save you from reimplementing a contract for many tests, 
they make implementing those contracts simpler in the first place.**

```java
// A basic starting point for a "fake" CreditService.
// It sets the foundation for many improvements, outlined below.
// You could even use a mock under the hood here, if you wanted. Part of the 
// benefit of a class is that you can change the implementation over time 
// without breaking your tests.
class InMemoryCreditService implements CreditService {
  private Map<AccountId, CreditStatus> accounts =
      ImmutableMap.of(AccountId.of(1), CreditStatus.HOLD);

  @Override
  public CreditStatus checkCredit(AccountId account) {
    return accounts.getOrDefault(account, CreditStatus.OK);
  }

  @Override
  public void charge(AccountId account, Money money) {
    if (CreditStatus.HOLD.equals(checkCredit(account))) {
      throw new NotEnoughCreditException();
    }
  }
}
```
[don't-spy]: https://javadoc.io/doc/org.mockito/mockito-core/latest/org/mockito/Mockito.html#13
[change-detector]: https://testing.googleblog.com/2015/01/testing-on-toilet-change-detector-tests.html

## Object-oriented test double

Admittedly, our class isn't all that impressive yet. We're just getting warmed up. **A classes real 
power comes from encapsulation.** A class is not just a collection of delicately specific stubs, but
a persistent, evolvable and cohesive implementation devoted to the problem of testing.

When all you need is a few stubbed methods, mocking libraries are great! **But the convenience of 
these libraries has made us forget that we can often do much better than a few stubbed methods.** 
Just as when we aimlessly add getters and setters, habitual mocking risks missing the point of 
object-orientation: objects as reusable, cohesive abstractions.

For example, test setup often has a higher order semantic meaning mock DSLs end up obfuscating. When
we stub an external service as in the example above... 

```java
when(creditService.checkCredit(AccountId.of(1))).thenReturn(HOLD);
doThrow(NotEnoughCreditException.class)
    .when(creditService).charge(AccountId.of(1), any(Money.class));
```

...what we are really saying is, "Account 1 is on credit hold." Rather than reading and writing a 
mock DSL that speaks in terms of methods and arguments and returning and throwing things, we can 
_name_ this whole concept as a method itself.

```java
// Evolving our class to do more for us
class InMemoryCreditService implements CreditService {
  private Map<AccountId, CreditStatus> accounts = new LinkedHashMap<>();

  public void assumeHoldOn(AccountId account) {
    accounts.put(account, CreditStatus.HOLD);
  }

  @Override
  public CreditStatus checkCredit(AccountId account) {
    return accounts.getOrDefault(account, CreditStatus.OK);
  }

  // charge implementation stays the same...
```

Using it, our test reads like our business speaks:

```java
creditService.assumeHoldOn(AccountId.of(1))
```

**Now this concept is reified for all developers to reuse (including your future self).** This is 
encapsulation: naming some procedure or concept that we may refer to it later. It builds the 
[ubiquitous language][ubiquitous-language] for your team and your tools. Having an obvious and 
discoverable place to capture and reuse a procedure or concept that comes up while testing: 
*that's* convenience.

I find myself using methods like these constantly while testing, further immersing my mind in the 
problem domain, and it is incredibly productive.

[ubiquitous-language]: https://martinfowler.com/bliki/UbiquitousLanguage.html

## Fakes over stubs

What we're discussing here so far is actually closer to a [{fake}][mocks-vs-stubs] than a {stub}. 
You've used a fake any time you've tested with an in-memory database. A fake is a complete 
implementation of some interface suitable for testing. As we've begun to elucidate, fakes are often 
very useful, and deserve a priority slot in our testing toolkit; slots too often monopolized by 
mocks.

As your class becomes more complete, it'll start to look more like a fake. What sets a fake apart 
really is that it usually has its own tests. **This ensures that when you use a test double instead 
of the real thing, you haven't invalidated your tests.** In this way, a fake also becomes a 
demonstration of how some type is supposed to work. It's a reference implementation, a testbed for 
experimentation, as well as documentation for ourselves, our teammates, and our successors. 

If you're clever, you can even reuse the same tests as your production implementation–and you 
should. It saves you time and gives you confidence. 

```java
// Example pattern to test a fake and production implementation against same tests

/** Defines the contract of a working repository via tests. */
abstract class RepositoryContract {
  SomeAggregateFactory factory = new SomeAggregateFactory();

  abstract Repository repository();

  @Test
  void savedAggregatesAreRetrievableById() {
    var aggregate = factory.newAggregate(repository().nextId());
    repository().save(aggregate);
    assertEquals(aggregate, repository().byId(aggregate.id()));
  }

  // etc...
}

class InMemoryRepositoryTest extends RepositoryContract {
  InMemoryRepository repository = new InMemoryRepository();

  @Override
  Repository repository() { return repository; }
}

class MongoRepositoryTest extends RepositoryContract {
  @RegisterExtension
  MongoDb mongoDb = new MongoDb();

  MongoRepository repository = new MongoRepository(mongoDb.database("test"));

  @Override
  Repository repository() { return repository; }
}
```

// Fakes can avoid cross-cutting, production, and operational concerns that cause a lot of complexity 
in test setup, and aren't the focus of most of your tests anyway. For example, they can just ignore 
solutions for nonvolatile persistence and high-performance concurrency control that we expect of our
production persistence abstractions, and which usually require a full database (such as in the 
example above, which would require downloading, starting, and managing a MongoDB process). An 
implementation can avoid the filesystem all together with in memory state, and can `synchronize` all
of its methods to quickly make it thread-safe.

[mocks-vs-stubs]: https://martinfowler.com/articles/mocksArentStubs.html#TheDifferenceBetweenMocksAndStubs

## Fakes as a feature

As the software industry is increasingly concerned with instrumenting code for observability and 
safe, frequent production rollouts, fakes increasingly make sense as a shipped _feature of our 
software_ rather than merely compiled-away test code. As a feature, fakes work as in-memory, 
out-of-the-box replacements of complicated external process dependencies and the burdensome 
configuration and coupling they bring along with them. **Running a service can then be effortless by 
way of a default, in-memory configuration**, also called a [hermetic server][hermetic-server] (as in 
"hermetically sealed"). As a feature, it is one of developer experience, though it still [profoundly
impacts customer experience through safer and faster delivery][accelerate].

The ability to quickly and easily start any version of your service with zero external dependencies 
is game changing. A new teammate can start up your services locally with simple system setup and one
command on their first day. Other teams can realistically use your service in their own testing, 
without understanding its ever-evolving internals, and without having to rely on expensive 
[enterprise-wide integration testing environments][test-environments], which inevitably [fail to 
reproduce production anyway][test-in-production]. Additionally, your service's own automated tests 
can interact with the entire application (testing tricky things like JSON serialization or HTTP 
error handling) and retain unit-test-like speed. And you can run them on an airplane.

// Fakes can even help test operational concerns. A colleague of mine recently needed to load test 
her service under certain, hard-to-reproduce conditions involving an external integration (a SaaS, 
no less). Rather than interrupting and waiting on the team which manages that SaaS, she simply 
reconfigured the service to use an in-memory fake. With such a fake you can even set up specific 
conditions of operation, like slow response times (a bit like a chaos experiment). Meanwhile, other 
dependencies, which needed to be load tested, kept their production, external configuration. She was
able to hammer some dependencies, which were under her control and supervision, while the rest were 
blissfully undisturbed. Her next release went off without a hitch.

[accelerate]: https://itrevolution.com/book/accelerate/
[hermetic-server]: https://testing.googleblog.com/2012/10/hermetic-servers.html
[test-environments]: https://www.thoughtworks.com/radar/techniques/enterprise-wide-integration-test-environments
[test-in-production]: https://www.honeycomb.io/blog/testing-in-production/

## This is your test. This is your test on drugs.

"Unit" tests–sometimes called "component" tests–in the ontology of testing, isolate a unit of code
to ensure it functions correctly. We often contrast these with "integration" tests (confusingly, 
sometimes also called component tests), which test units together, without isolation. We heard 
writing lots of unit tests is good, because of something about a [pyramid and an ice cream 
cone][move-fast-don't-break-things], so we have to make sure most of our tests only use isolated 
units, so that most of our tests are unit tests.

So let's back up. **Why are we "isolating units" in the first place?**

* With fewer dependencies, there is fewer places to look when there is a test failure. This means we
can fix bugs faster, so we can _ship to our users more frequently_.
* Dependencies can be heavy, like databases or other servers which take time to set up, slowing down
the tests and their essential feedback. Replacing those with fast test doubles means faster feedback
cycles, and faster feedback cycles means we can _ship to our users more frequently_.

These two [why stacks][why-stacks] all eventually converge at the same reason, **the reason we 
write tests in the first place: to ship more value, more quickly** (after all, [features which 
improve safety also improve speed][beyond-ops]). While replacing collaborators can help as 
described, replacing collaborators *also* has effects directly counter to this end goal. Because 
those replacements aren't what we actually ship, **when you replace dependencies, your feedback 
cycles slow down** because you aren't actually seeing your code as it truly works until you deploy 
and get it in front of users. If you don't have good monitoring, you may not even see it then.

> Mocks are like hard drugs... the more you use, the more separated from reality everything 
> becomes.^[1]

---

^1: Thank you Lex Pattison for this [fantastic quote.](https://testing.googleblog.com/2013/05/testing-on-toilet-dont-overuse-mocks.html?showComment=1369929860616#c5181256978273365658)

## All tests are integration tests

If we think about our testing decisions in terms of value throughput (which is the only thing that 
matters) instead of fixating on isolating units, we end up making very different decisions:

1. **Don't replace a dependency unless you have a really good reason to**. We've talked 
about some good examples of when this makes sense already: heavy dependencies, like external process 
integrations, in which the complexity or time justifies the expense of replacing it. Fakes, as 
described above, work great here.

2. **Write your production code so you can reuse as much of it in tests as possible.** In 
particular, encapsulate your business logic, of which there is really only one correct 
implementation by definition, in a reusable class with otherwise injected dependencies. 

By avoiding doubles at all, you've saved yourself the time of reimplementing code you've already 
written and already tested. More importantly, your tests aren't lying to you; they actually provide 
meaningful feedback.

Unit testing, if defined by isolating a test to only one class, doesn't exist. No code exists in
a vacuum. In this way, **all tests are integration tests.** Rather than think about unit vs 
integration vs component vs end to end or whatever, I recommend sticking to Google's pragmatic 
[small, medium, and large][test-sizes] test categorization.

If you're getting hives thinking about all the places bugs could lurk without isolating a unit–I 
used to–ask yourself, why are we so comfortable using the standard library, or Apache commons, or 
Guava, without mocking that code out too? We trust that code. Why? **We trust code that has its 
own tests.**^[2]

The same can be true of our own code. If we organize our code in layers, where each layer depends on
a well-tested layer beneath it, we rarely need to replace dependencies with test doubles at all. The
bug shouldn't be there, because we've tested it, mitigating one of the "cons" of integration.

<div class="separator" style="clear: both;"><a href="https://1.bp.blogspot.com/--wWnJ8UntFU/X53cMnbuReI/AAAAAAAAWbA/P4krjkQNHr8AlhYEZrstPfYLk4LhjrCrgCPcBGAYYCw/s2048/app_architecture.png" style="display: block; padding: 1em 0; text-align: center; "><img alt="" border="0" height="600" data-original-height="2048" data-original-width="1948" src="https://1.bp.blogspot.com/--wWnJ8UntFU/X53cMnbuReI/AAAAAAAAWbA/P4krjkQNHr8AlhYEZrstPfYLk4LhjrCrgCPcBGAYYCw/s600/app_architecture.png"/></a></div>

// This can also be visualized as a hexagon, known as a ["hexagonal" or "ports and 
adapters" architecture][hexagonal-architecture].

You will find tests at each layer may feel redundant. The scenarios will be similar or even the 
same, and will exercise much of the same code, as lower-layer tests. For example, you might have a 
test "places order with account in good credit standing" at the application layer invoked via the 
HTTP transport, at the application services layer invoking these classes directly, and at the domain
model layer.

```java
// Use your production Spring Boot configuration, but with an in-memory profile
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
@ActiveProfiles("in-memory")
class ApplicationTest {
  // snip...
  
  @Autowired
  InMemorySubscriptions subscriptions;

  // A larger test, with broad scope and slow startup due to Spring and 
  // web server initialization. We're not just testing business logic,
  // but particularly focused on the transport specifics and application 
  // wiring.
  @Test
  void placesOrderWithAccountInGoodCreditStanding() {
    // assume some requests to define the subscriptions in an order...

    assertOk(restTemplate.postForEntity(
        "/v1/orders/1/",
        new HttpEntity<>(ImmutableMap.of("account", 1)),
        Map.class));
    
    assertThat(subscriptions.forAccount(AccountId.of(1))).hasSize(1);
  }
  
  // Other tests here need not all be business scenarios; they may be
  // error scenarios, particularly focused on the HTTP specifics like
  // status codes and serialization, etc.
}

// Medium tests; fast but still broad.
// Requires a Spring context for security features, maybe transactions,
// or metrics, but doesn't require a web server.
@SpringJUnitConfig
class OrderApplicationServiceTest {
  // snip...

  @Test
  void placesOrderWithAccountInGoodCreditStanding() {
    var order = orderService.startOrder(Subscription.of("SKU1"))
    orderService.charge(order.id(), AccountId.of(1));
    assertThat(subscriptions.forAccount(AccountId.of(1))).hasSize(1);
  }
}

// Small test; fast and limited to only our domain model package.
// Requires no framework.
class OrderProcessorTest {
  InMemoryCreditService creditService = new InMemoryCreditService();
  InMemorySubscriptions subscriptions = new InMemorySubscriptions();
  OrderProcessor orderProcessor = new OrderProcessor(creditService, subscriptions);
  OrderFactory orderFactory = new OrderFactory();

  @Test
  void processesOrderWithAccountInGoodCreditStanding() {
    var order = orderFactory.startOrder();
    order.addSubscription(Subscription.of("SKU1"));
    orderProcessor.process(AccountId.of(1), order);
    assertThat(subscriptions.forAccount(AccountId.of(1))).hasSize(1);
  }
}
```

I used to fight really hard with my tests to avoid this overlap. 

It was far more trouble than it was worth.

The thing is, these aren't actually that redundant when you think about it. Remember, when you or 
your teammates uses some class in your application, you expect it to adhere to its contract; period.
This is what tests do–assert things implement their contracts. How they implement them doesn't 
matter to your tests, and nor should it matter to you (otherwise, how can you hope to survive in a 
complex code base if you have to keep the whole thing in your head?). If one of these tests fail, 
yes, it's quite possible the problem is in another class instead of the one under test. But as we
discussed, you should also have tests against _that_ class. And if this case is missing, great!
You found a missing test, and a bug! You wouldn't have found this bug (until production, if at all)
if you replaced the dependency with a mock, and what is the point of tests if not to discover bugs 
before production?

I also picked an extreme example. In practice, tests at lower levels get much more detailed, 
thoroughly testing all branches in your domain objects, since that's where most of your business 
logic is (or should be) anyway. Individual upper layers likely won't be able to reach all those 
branches, and don't really need to try. As a result, you end up with a familiar test pyramid, with
lots of small, fast tests, and fewer larger, slow tests.

<div class="separator" style="clear: both;"><a href="https://1.bp.blogspot.com/-3FD0rEPXtDg/X58wwHQqwdI/AAAAAAAAWdw/5tmFjNH0khojczBXEsslNYlfIVXnr7GXACLcBGAsYHQ/s0/Test%2Bpyramid.png" style="display: block; padding: 1em 0; text-align: center; "><img alt="" border="0" data-original-height="426" data-original-width="694" src="https://1.bp.blogspot.com/-3FD0rEPXtDg/X58wwHQqwdI/AAAAAAAAWdw/5tmFjNH0khojczBXEsslNYlfIVXnr7GXACLcBGAsYHQ/s0/Test%2Bpyramid.png"/></a></div>

What redundancy there is merely a reflection of the obvious: code relies on other code. And by 
definition that means when we test code, we're (re)testing other code, whether we wrote it or not, 
all the time. By accepting it, you've freed yourself up to reuse an entire application of code 
rather than replacing it throughout your tests, and you know your tests actually reflect 
reality^[3].

[brain-on-tidiness]: https://www.cnn.com/style/article/this-is-your-brain-on-tidiness/index.html
[move-fast-don't-break-things]: https://docs.google.com/presentation/d/15gNk21rjer3xo-b1ZqyQVGebOp_aPvHU3YH7YnOMxtE/edit#slide=id.g437663ce1_53_98
[why-stacks]: https://mikebroberts.com/2003/07/29/popping-the-why-stack/
[beyond-ops]: https://www.heavybit.com/library/podcasts/o11ycast/ep-23-beyond-ops-with-erwin-van-der-koogh-of-linc/
[test-sizes]: https://testing.googleblog.com/2010/12/test-sizes.html
[hexagonal-architecture]: https://alistair.cockburn.us/hexagonal-architecture/

---

^2: For further exploration of tested or "well understood" as the boundary for "unit" vs 
"integration" tests, check out the legendary Kent Beck's post, ["Unit" 
Tests?](https://www.facebook.com/notes/kent-beck/unit-tests/1726369154062608/).

^3: Admittedly, the only reality is actual production, which is why testing mustn't stop at the door
of prod, but embrace it through monitoring, observability, feature flags, and the like. But there's 
no reason you shouldn't try to get close to production on your laptop, especially where doing so 
saves you so much time to boot.

## Closing thoughts 

* Mostly, tools are not bad or good. We must remember to use them with intention. 
* Reuse your existing, well-tested implementations where you can. Strive to make your classes
reusable in tests. Never stub or fake business logic.
* Start tests from your core types and work outward, focusing on the testing the contract of the 
class under test. Don't worry if the tests are somehow redundant with other tests–that's a matter
of implementation. What matters is the class, in conjunction with obedient collaborators, implements
its own contract.
* When using the real thing is harmful (such as too complex or slow to set up), ensure you've first 
isolated through abstraction. Then, fake the abstraction. Write tests that run against both the fake
and the real implementation to ensure the fake is compliant.
* Capture common set up scenarios in the language of your problem domain as methods on your fakes.
* Compile your fakes with your program, and put them behind configuration flags or profiles to 
enable lightweight modes of execution.
 
[don't-overuse-mocks]: https://testing.googleblog.com/2013/05/testing-on-toilet-dont-overuse-mocks.html
[mocks-are-stupid]: https://www.endoflineblog.com/testing-with-doubles-or-why-mocks-are-stupid-part-4#2-mocks-are-stupid-and-so-are-stubs-
[service-call-contracts]: https://testing.googleblog.com/2018/11/testing-on-toilet-exercise-service-call.html
