<meta name="id" content="7799320222051028141">
<meta name="labels" content="testing,object oriented programming,java,microservices,domain-driven design">
<meta name="title" content="The secret world of testing without mocking: domain-driven design, fakes, and other patterns to simplify testing in a microservices architecture">
<meta name="description" content="How to simplify microservice testing through a few simple 
applications of domain-driven design and in-memory test doubles (fakes).">

Much has been said about mocks, the controversial, swiss-army knife of test doubles. Mocking has
become so ubiquitous due to the popularity, flexibility, and convenience of mocking libraries like 
Mockito, [one of the most used Java libraries in the world][mockito-popularity]. Mockito makes it 
so easy to quickly fashion a simple mock or stub, that not only do we forget there is even [a 
difference there][mocks-arent-stubs], but I also suspect we forget there are still more options, 
like their older and wiser cousin, the humble {fake}. {Fakes} are "objects [that] actually have 
working implementations, but usually take some shortcut which makes them not suitable for 
production (an in memory database is a good example)."^[1]

// While "mocking" is an abstract concept, for the remainder of this post I'll use the term mock to
refer specifically to a mock or stub configured by way of a mocking library like Mockito.

Fakes are perceived as heavy and burdensome to implement. However, often their "heaviness" is a sign
of some other problem, such as a missing abstraction, in which case solving the root problem (rather 
than pasting over it with a mock) not only makes it simpler to implement the fake, but also makes it
simpler to evolve the rest of your code that otherwise risks festering into expensive technical debt
(if it hasn't already). Other times the initial effort required to implement a fake is unavoidable, 
but is matched or exceeded by the ensuing value of a persistent class which encapsulates test 
interaction with a particular dependency.

At the very least, we spend too much of our time writing tests for our toolkit to be monopolized by 
a single tool. To ensure we're using the right one for the job, let's remind ourselves of a world
without mocks, and the system of incentives, practices, and abstractions that evolve as a 
result.

---

^1: For this and other definitions of test doubles like stubs and fakes, see Martin Fowler's 
[Mocks Aren't Stubs][mocks-arent-stubs].

[mockito-popularity]: https://docs.google.com/spreadsheets/u/0/d/1aMNDdk2A-AyhpPBnOc6Ki4kzs3YIJToOADeGjCrrPCo
[mocks-arent-stubs]: https://martinfowler.com/articles/mocksArentStubs.html

## The hidden burdens of mocking

## Fakes as a demonstration

Another way I like to think about a fake is a _demonstration_ of how some type is supposed to work. 
This serves as a reference implementation, a testbed for experimentation, as well as documentation 
for ourselves, our teammates, and our successors. Not only that, but as a class of its own, it can 
also get its own tests. In fact, if you're clever, you can even test your fake against the same 
tests as your production implementation–and you should. This ensures that when you use a test double 
instead of the real thing, you haven't invalidated your tests.

// Fakes can avoid cross-cutting, production, and operational concerns that cause a lot of 
complexity in test setup, and aren't the focus of most of your tests anyway. For example, they can 
just ignore solutions for nonvolatile persistence and high-performance concurrency control that we 
expect of our production persistence abstractions, and which usually require a full database. An 
implementation can avoid the filesystem all together with in memory state, and can `synchronize` all
of its methods to quickly make it thread-safe. TODO: appendix about in-memory repositories

## Fakes as a feature

We have still only scratched the surface. As the software industry is increasingly concerned
with instrumenting code for observability and [safe, frequent production 
rollouts](https://itrevolution.com/book/accelerate/), fakes increasingly make sense as a shipped 
_feature of our software_ rather than merely compiled-away test code. As a feature, fakes work as 
in-memory, out-of-the-box replacements of complicated external process dependencies and the 
burdensome configuration and coupling they bring along with them. Running a service can then be 
effortless by way of a default, in-memory configuration, also called a [hermetic 
server](https://testing.googleblog.com/2012/10/hermetic-servers.html) (as in hermetically sealed). 
As a feature, it is one of developer experience, though it still profoundly impacts, if indirectly, 
customer experience, through safer and faster delivery.

This accessibility is revolutionary. A new teammate can start up your services locally with simple
system setup and one command on their first day. Other teams can realistically use your service, 
without understanding its ever-evolving internals, in integration testing. Your projects own 
automated tests can interact with the whole service and retain unit-test-like speed. And it can all 
be done on airplane-mode.

Fakes can even help test operational concerns. A colleague of mine recently needed to load test her
service under certain, hard-to-reproduce conditions involving an external integration (a SaaS, no 
less). Rather than interrupting and waiting on the team which manages that SaaS, she simply 
reconfigured the service to use an in-memory fake. Other dependencies, which needed to be load 
tested, kept their production, external configuration. She was able to hammer some dependencies,
which were under her control and supervision, while the rest were blissfully undisturbed. Her next 
release went off without a hitch.
