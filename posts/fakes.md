<meta name="id" content="7799320222051028141">
<meta name="labels" content="testing,object oriented programming,java,microservices,domain-driven design">
<meta name="title" content="The secret world of testing without mocking: domain-driven design, fakes, and other patterns to simplify testing in a microservice architecture">
<meta name="description" content="How to simplify microservice testing through a few simple 
applications of domain-driven design and in-memory test doubles (fakes).">

Much has been said about mocks, the controversial, Swiss army knife of test doubles: don't use them
too much, when to verify state or when to verify interactions, don't test implementation detail, 
don't mock types you don't own, only mock classes when dealing with legacy code, don't mock complex 
interfaces; the list goes on. For a tool so easy to misuse, it sure seems like we're using it a lot.
Mockito is [one of the most used Java libraries in the world][mockito-popularity].

// While "mocking" is an abstract concept, for the remainder of this post I'll use the term mock to
refer specifically to a mock or stub configured by way of a mocking library like Mockito. Likewise,
when I refer to Mockito, I really mean any mocking library; Mockito just stands out because it has
a great API and is–no doubt as a consequence–measurably very popular.

I was there too, once a frequent Mockito user, perhaps like you are now. Over time however, as my 
application architectures improved, as I began to introduce [real domain 
models][anemic-architecture-testing], the tests I wrote were becoming simpler, easier to add, and 
services easier to develop. Tricky testing problems that loomed over my head for years now had 
obvious solutions. Much to my surprise, I was barely using Mockito at all.

In this post, I demonstrate some compelling and, in my experience, overlooked advantages to mock 
alternatives. We will explore the origins of mocking, why mocking may have become so ubiquitous, a 
world without mocking, and the system of incentives, practices, and abstractions that evolve as a 
result. Whether you are a casual or devout mock-ist, I encourage you to keep calm, open your mind, 
and try going without for a while. This post will guide you. You may be surprised what you find.

[mockito-popularity]: https://docs.google.com/spreadsheets/u/0/d/1aMNDdk2A-AyhpPBnOc6Ki4kzs3YIJToOADeGjCrrPCo
[anemic-architecture-testing]: http://qala.io/blog/anaemic-architecture-enemy-of-testing.html

## The hidden burdens of mocking

We forget because the APIs are so nice, but mocking is fascinatingly complex under the hood. It's 
{metaprogramming}: code that implements types at runtime rather than using native language features
to implement types at compile time. Runtime metaprogramming affords the spectacular opportunity to 
design domain-specific languages (DSLs) that implement types with semantics, defaults, and syntax 
different from that of the native Java `class`. For example, with Mockito, we can implement a large 
interface with one line rather than tens or hundreds implementing every method with a no-op 
(although to be fair, any IDE can generate the same thing in a second). Mockito's API optimizes for 
immediate convenience–justifiably so–but its this immediate convenience that dominates our thinking. 
While less sexy, a compile-time implementation, aside from fewer surprises, has its own 
conveniences. Unfortunately, they are subtle and easily overlooked. This is not to be confused with
insignificant. Quite the contrary, these "conveniences" are profound. Let's dig in.

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
// inside a container works, the process couldn't attach an agent to itself.

When a class under test has a mocked dependency, the dependency must be stubbed according to the 
needs of your test. (Of course, unless you use a spy, but you're not really supposed to use 
those; [just ask Mockito's authors][don't-spy].) We don't want to bother stubbing all the methods 
out, so we only stub the ones our test needs. Similarly, we don't want to implement state or much 
logic, so just implement the method say forcertain arguments, and return some result. Over time, as 
we add more and more tests, or our classes or dependencies evolve, a few patterns emerge.

First of all, in this short-hand stubbing pattern, our tests are [relying on the implementation of 
our class][don't-overuse-mocks] in subtle ways. By leaving out stubbing some methods, we imply we 
know _what_ methods are used. By only stubbing for certain arguments, we imply we know _how_ those 
methods are used. If our [implementation changes, we may need to update our tests][change-detector],
even though they are still testing the same scenario. Likewise, each time we write a new test, we 
must recall how the dependency is _used_, so we stub it the right way.

// TODO: example

Secondly, tests are repeating the contract of the dependency. That is, as the dependency changes, 
any tests stubbing it may need to update to conform to its updated contract. Likewise, as we add 
more tests, we must also recall how the dependency _works_, so we stub it the right way. For 
example, if an interface encapsulates some state between subsequent method calls, or a method has 
some preconditions or postconditions, and [your stub does not reimplement these 
correctly][mocks-are-stupid], your tests may pass even though the system-under-test is not correct 
(or vice versa).

To remove some of this repetition, some might simply refactor the test setup to be done once in one 
`@BeforeEach` method for the whole class. But what about the next class that uses this dependency?
Okay, fine, pull out the test setup into other reusable classes which stub dependencies for you.
Then, reuse that in each test class.

// TODO: example

There is another way to make an implementation of a type reusable so that you don't have to 
constantly reimplement it: the familiar, tool-assisted, keyword-supported, fit-for-purpose class. 
Classes are built-in to the language to solve precisely this problem of capturing and codifying 
knowledge for reuse in a stateful type. Write it once, and it sticks around to help you with the 
next test. Not only do classes elegantly save you from reimplementing a contract for many tests, 
they make implementing those contracts simpler in the first place. Need a place for persistent state
within the type? Well, now you have fields of course. It's easy to take for granted all the humble 
class can do for us.

// TODO: example

[don't-spy]: https://javadoc.io/doc/org.mockito/mockito-core/latest/org/mockito/Mockito.html#13
[don't-overuse-mocks]: https://testing.googleblog.com/2013/05/testing-on-toilet-dont-overuse-mocks.html
[change-detector]: https://testing.googleblog.com/2015/01/testing-on-toilet-change-detector-tests.html
[mocks-are-stupid]: https://www.endoflineblog.com/testing-with-doubles-or-why-mocks-are-stupid-part-4#2-mocks-are-stupid-and-so-are-stubs-

## Object-oriented test double

Yet, classes are still more than that. Their real power comes from encapsulation. A class is not 
just a collection of delicately specific stubs, but a persistent, evolvable and cohesive 
implementation devoted to the problem of testing.

When all you need is a few stubbed methods, mocking libraries are great! **But the convenience of 
these libraries has made us forget that we can often do much better than a few stubbed methods.** 
Just as when we aimlessly add getters and setters, habitual mocking risks missing the point of 
object-orientation: objects as reusable, cohesive abstractions.

For example, test setup often has a higher order semantic meaning mock DSLs end up obfuscating. When
we stub an external service like... 

```java
var creditService = mock(CreditService.class);
when(creditService.checkCredit(AccountId.of(1))).thenReturn(HOLD);
doThrow(NotEnoughCreditException.class).when(creditService).charge(AccountId.of(1), any(Money.class));
```

...what we are really saying is, "Account 1 is on credit hold." Rather than reading and writing a 
mock DSL that speaks in terms of methods and arguments and returning and throwing things, we can 
_name_ this whole concept as a method itself.

```java
var creditService = new InMemoryCreditService();
creditService.placeHoldOn(AccountId.of(1))
```

Now this concept is reified for all developers to reuse (including your future self). **This is 
encapsulation**: naming some procedure or concept that we may refer to it later. It builds the 
[ubiquitous language][ubiquitous-language] for your team and your tools. Having an obvious and 
discoverable  place to capture and reuse a procedure or concept that comes up while testing: 
*that's* convenience.

// You might argue you could put those two stubbing calls in one similarly named method on a class,
but what if another test class needs a `CreditService`, now or in the future? Keep in mind, if you
really wanted, you could still use a mock DSL under the hood of your class, and in that case the 
difference in upfront effort is completely negligible. That said, you may find at some point it 
makes sense to start using native class features to implement logic instead of metaprogramming. In 
fact, this is another advantage of using a class: our tests aren't coupled to whether the thing is a
mock or whatever; they simply get readable, stable, and reusable test setup.

I find myself adding and using methods like these constantly while testing, further immersing my 
mind in the problem domain, and it is incredibly productive.

[ubiquitous-language]: https://martinfowler.com/bliki/UbiquitousLanguage.html

## Fakes as a demonstration

What we're discussing here so far is actually closer to a [{fake}][mocks-vs-stubs] than a {stub}. A
fake is a complete reimplementation of some interface suitable for testing. As we've begun to 
elucidate, fakes are often very useful, and deserve a priority slot in our testing toolkit; slots 
too often monopolized by mocks.

Another way I like to think about a fake is a _demonstration_ of how some type is supposed to work. 
This serves as a reference implementation, a testbed for experimentation, as well as documentation 
for ourselves, our teammates, and our successors. Not only that, but as a class of its own, it can 
also get its own tests. In fact, if you're clever, you can even test your fake against the same 
tests as your production implementation–and you should. This ensures that when you use a test double 
instead of the real thing, you haven't invalidated your tests.

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

Fakes can avoid cross-cutting, production, and operational concerns that cause a lot of complexity 
in test setup, and aren't the focus of most of your tests anyway. For example, they can just ignore 
solutions for nonvolatile persistence and high-performance concurrency control that we expect of our
production persistence abstractions, and which usually require a full database (such as in the 
example above, which would require downloading, starting, and managing a MongoDB process). An 
implementation can avoid the filesystem all together with in memory state, and can `synchronize` all
of its methods to quickly make it thread-safe.

// TODO: appendix about in-memory repositories

[mocks-vs-stubs]: https://martinfowler.com/articles/mocksArentStubs.html#TheDifferenceBetweenMocksAndStubs

## Fakes as a feature

As the software industry is increasingly concerned with instrumenting code for observability and 
[safe, frequent production rollouts][accelerate], fakes increasingly make sense as a shipped 
_feature of our software_ rather than merely compiled-away test code. As a feature, fakes work as 
in-memory, out-of-the-box replacements of complicated external process dependencies and the 
burdensome configuration and coupling they bring along with them. Running a service can then be 
effortless by way of a default, in-memory configuration, also called a [hermetic 
server][hermetic-server] (as in hermetically sealed). As a feature, it is one of developer 
experience, though it still profoundly impacts, if indirectly, customer experience, through safer 
and faster delivery, among other things.

This accessibility is revolutionary. A new teammate can start up your services locally with simple
system setup and one command on their first day. Other teams can realistically use your service in
their own testing, without understanding its ever-evolving internals, and without having to rely on
expensive [enterprise-wide integration testing environments][test-environments], which inevitably 
[fail to reproduce production anyway][test-in-production]. Additionally, your service's own 
automated tests can interact with the entire application (testing tricky things like JSON 
serialization or HTTP error handling) and retain unit-test-like speed. And it can all be done on 
airplane-mode.

Fakes can even help test operational concerns. A colleague of mine recently needed to load test her
service under certain, hard-to-reproduce conditions involving an external integration (a SaaS, no 
less). Rather than interrupting and waiting on the team which manages that SaaS, she simply 
reconfigured the service to use an in-memory fake. Other dependencies, which needed to be load 
tested, kept their production, external configuration. She was able to hammer some dependencies,
which were under her control and supervision, while the rest were blissfully undisturbed. Her next 
release went off without a hitch.

[accelerate]: https://itrevolution.com/book/accelerate/
[hermetic-server]: https://testing.googleblog.com/2012/10/hermetic-servers.html
[test-environments]: https://www.thoughtworks.com/radar/techniques/enterprise-wide-integration-test-environments
[test-in-production]: https://www.honeycomb.io/blog/testing-in-production/

## Fakes vs Reals, or The Futility of Isolation

We humans are innately preoccupied with organizing our thoughts and concepts with ontologies and 
taxonomies. [Sorting just makes us feel like we're doing something *good* and 
*productive*.](https://originalcontentbooks.com/blog/organize-things-to-get-more-done) I feel all 
cozy inside just thinking about it.

// TODO: also see https://www.cnn.com/style/article/this-is-your-brain-on-tidiness/index.html

Perhaps you a recall of tinge of satisfaction when you've added yet another subpackage inside your 
Java project?

"Unit" tests–sometimes called "component" tests–in the ontology of testing, isolate a unit of code
to ensure it functions correctly. We often contrast these with "integration" tests (confusingly, 
sometimes also called component tests), which test units together, without isolation. We heard 
writing lots of unit tests is good, because of something about a 
[pyramid and an ice cream cone][move-fast-don't-break-things],
so we have to make sure most of our tests only use isolated units, so that most of our tests are 
unit tests.

"Unit" is intentionally though unfortunately ambiguous, which means naturally, over time, it 
devolved. Most developers take this to mean "class" or "method", and so we became hyperfocused on 
isolating a class or method under test from all others.

// Listen to some of these overreactions at the suggestion that we 
[may be trying too hard to isolate](https://testing.googleblog.com/2013/05/testing-on-toilet-dont-overuse-mocks.html):
// 
// * <q>Also it's called unit testing for a reason, testing dependencies is a nono.</q>
// * <q>The whole point of unit testing is that you are attempting to test a unit of functionality.</q>
// 
// Both of these commenters are falling into the same meaningless, circular trap: _"You can't test 
// dependencies in a unit test because unit tests don't test dependencies."_

So let's back up. We've been talking a lot about replacing dependencies with mocks or stubs or 
fakes. Why are we replacing dependencies in the first place? What about just using the "reals"?

* We'd like the cause of failures to be clear. Fewer dependencies means fewer places to look for a 
bug. Fewer places to look means faster diagnoses. If we can fix bugs faster, then _users see features 
and fixes more frequently_. 
* We'd like to have fast tests. Dependencies can be heavy, like databases or other
servers which take time to set up, slowing down the tests and their essential feedback. Replacing 
those with fast test doubles means faster feedback cycles, which means we can _ship to our users 
more frequently_.
* We'd like tests to be easy to write, so we can write many, gain lots of confidence, ship less 
bugs. With less bugs to worry about, we can _spend more time shipping features over fixes_.

These three [why stacks](https://mikebroberts.com/2003/07/29/popping-the-why-stack/) all eventually
converge at the same reason, the reason we write tests in the first place: to ship more value,
more quickly (after all, 
[features which improve safety also improve speed](https://www.heavybit.com/library/podcasts/o11ycast/ep-23-beyond-ops-with-erwin-van-der-koogh-of-linc/)).
While replacing collaborators can help as described, replacing collaborators *also* has effects 
directly counter to this end goal; namely, _those replacements aren't what we actually ship_. If you 
go too far with mocking, what actually happens is that your feedback cycles _slow way down_ because 
**you aren't actually seeing your code as it truly works until you deploy and get it in front of 
users**.

> Mocks are like hard drugs... the more you use, the more separated from reality everything becomes.
[(source)](https://testing.googleblog.com/2013/05/testing-on-toilet-dont-overuse-mocks.html?showComment=1369929860616#c5181256978273365658)

This is why I'm complaining about testing ontologies. Sometimes simplifications of complex spaces 
end up [thought-terminating](https://en.wikipedia.org/wiki/Thought-terminating_clich%C3%A9), much 
like mocks themselves. If we think about our testing decisions in terms of value throughput (which 
is the only thing that matters) instead of the predispositions of the testing models we happen to 
subscribe to, we end up making very different decisions. Specifically, **don't replace a dependency 
unless you have a really good reason to**. We've talked about some good examples of when this makes
sense already: heavy dependencies, like external process integrations. These deserve fakes as 
described above. Secondly, and equally important, **write your production code so you can reuse as 
much of it in tests as possible**, especially business logic, of which there is really only one 
correct implementation by definition. By avoiding doubles at all, you've saved yourself the time
of reimplementing code you've already written, and your tests aren't lying to you; they actually 
provide feedback your users care about.

// This is the same reason we don't just throw interfaces everywhere even though we might think it
makes our code more "flexible." Flexibility isn't always _good_; a business rule is a business rule,
unless your business model specifically models possible alternatives, there is only one correct 
implementation. If there is only one correct implementation, then what you want is a class, not an
interface. Incidentally, mocking libraries generally only encourage you to mock interfaces, not
classes.

Unit testing, if defined by isolating only your class under test, doesn't exist. [No code exists in
a vacuum](https://www.facebook.com/notes/kent-beck/unit-tests/1726369154062608/). In this way, 
**all tests are integration tests.** Rather than think about unit vs integration vs end to end or 
whatever, I recommend sticking to Google's [small, medium, and 
large](https://testing.googleblog.com/2010/12/test-sizes.html) test categorization. If you're 
getting hives thinking about all the places bugs could lurk without isolating a unit–I used to–ask
yourself, why are we so comfortable then using the standard library or Apache commons or Guava
without mocking that code out too? We trust that code. Why? We trust code **that has its own 
tests.**

The same can be true of our own code. If we organize our code in layers, with business logic deep in
our domain model, infrastructure defined by interfaces and anti-corruption layers, used by application services in the middle, used by an HTTP adapter on top (or
whichever protocol for this [port](https://alistair.cockburn.us/hexagonal-architecture/)), each layer

// TODO: diagram this, will be easier to describe 


  
* tests in layers - domain model mostly isolated, then services, then application services, then
http layer – each layer tests the others, too, but does not focus on them – it's about the contract
at each layer.
* what is the harm here? if a test fails, it might be because of a lower layer. so what? you've 
discovered a bug. add a test for that bug at the appropriate layer and fix it. compare to if you
isolated the bugged dependency with a stub, you'd never discover the real bug until production. what
is the point of tests if not to discover bugs before production? mocks make it reflexively easy to
end up testing a substantial amount of code that never actually runs.

[move-fast-don't-break-things]: https://docs.google.com/presentation/d/15gNk21rjer3xo-b1ZqyQVGebOp_aPvHU3YH7YnOMxtE/edit#slide=id.g437663ce1_53_98
