<meta name="id" content="7799320222051028141">
<meta name="labels" content="testing,object oriented programming,java,microservices,domain-driven design">
<meta name="title" content="The secret world of testing without mocking: domain-driven design, fakes, and other patterns to simplify testing in a microservices architecture">
<meta name="description" content="How to simplify microservice testing through a few simple 
applications of domain-driven design and in-memory test doubles (fakes).">

Much has been said about mocks, the controversial, swiss-army knife of test doubles. Mocking has
become so ubiquitous due to the popularity, flexibility, and convenience of mocking libraries like 
Mockito, [one of the most used Java libraries in the world][mockito-popularity], that I think we may
have forgotten there are [still more options][mocks-arent-stubs], like their older and wiser cousin,
the humble {fake}. {Fakes} are "objects [that] actually have working implementations, but usually 
take some shortcut which makes them not suitable for production (an in memory database is a good 
example)."^[1]

// While "mocking" is an abstract concept, for the remainder of this post I'll use the term mock to
refer specifically to a mock or stub configured by way of a mocking library like Mockito.

Fakes may be perceived as heavy and burdensome to implement. However, often their "heaviness" is a 
sign of some other problem, such as a missing abstraction, in which case solving the root problem 
(rather than pasting over it with a mock) not only makes it simpler to implement the fake, but also 
makes it simpler to evolve the rest of your code that otherwise risks festering into expensive 
technical debt (if it hasn't already). Other times the initial effort required to implement a fake 
is unavoidable, but is quickly matched or exceeded by the ensuing value of a persistent class which 
encapsulates test interaction with a particular dependency.

At the very least, we spend too much of our time writing tests for our toolkit to be monopolized by 
a single tool. To ensure we're using the right one for the job, let's remind ourselves of a world
without mocks, and stick around long enough to discover the system of incentives, practices, and 
abstractions that evolve as a result.

---

^1: For this and other definitions of test doubles like stubs and fakes, see Martin Fowler's 
[Mocks Aren't Stubs][mocks-arent-stubs].

[mockito-popularity]: https://docs.google.com/spreadsheets/u/0/d/1aMNDdk2A-AyhpPBnOc6Ki4kzs3YIJToOADeGjCrrPCo
[mocks-arent-stubs]: https://martinfowler.com/articles/mocksArentStubs.html

## The hidden burdens of mocking

We forget because the APIs are so nice, but mocking is fascinatingly complex under the hood. It's 
meta-programming: code that implements types at runtime rather than using native language features
to implement types at compile time. Implementing types at runtime means you can design a custom 
means for defining implementation with alternative semantics, defaults, and syntax than the native
Java way. This can result in an initial convenience that dominates our thinking. For example, with 
Mockito, we can implement a large interface with one line rather than tens or hundreds implementing 
every method with a no-op (although to be fair, any IDE can generate the same thing in a second). 
That said, while less sexy, a compile-time implementation, aside from fewer surprises, has its own 
conveniences. Let's give those some attention.

// TODO: story of build issues due to mockito runtime agent installation and user OS permissions

When a class under test has a mocked dependency, the dependency must be stubbed according to the 
needs of your test.

// Of course, unless you use a spy. But, you're not really supposed to use those. Just [ask 
Mockito's authors][dont-spy].

We don't want to bother stubbing all the methods out, so we only stub the ones our test needs. 
Similarly, we don't want to implement state or much logic, so just implement the method say for
certain arguments, and return some result. Over time, as we add more and more tests, or our classes 
or dependencies evolve, a few patterns emerge.

First of all, in this short-hand stubbing pattern, our tests are [relying on the implementation of 
our class][dont-overuse-mocks] in subtle ways. By leaving out stubbing some methods, we imply we 
know _what_ methods are used. By only stubbing for certain arguments, we imply we know _how_ those 
methods are used. If our implementation changes, we may need to update our tests, even though they 
are still testing the same scenario. Likewise, each time we write a new test, we must recall how the
dependency is used, so we stub it the right way.

// TODO: example

Secondly, tests are repeating the contract of the dependency. That is, as the dependency changes, 
any tests stubbing it may need to update to conform to its updated contract. Likewise, as we add 
more tests, we must again recall how the dependency works, so we stub it the right way. For example,
if an interface encapsulates some state between subsequent method calls, or a method has some
preconditions or postconditions, and [your stub does not reimplement these 
correctly][mocks-are-stupid], your tests may pass even though the system-under-test is not correct 
(or vice versa).

To remove some of this repetition, some might simply refactor the test setup to be done once in one 
`@BeforeEach` method for the whole class. But what about the next class that uses this dependency?
Okay, fine, pull out the test setup into other reusable classes which stub dependencies for you.
Then, reuse that in each test class.

I've seen this. You know another way to make an implementation of a class reusable so that you don't
have to constantly reimplement it? That's right: writing a class! No, not the meta-programming way;
the good ol'-fashioned Java way.

If you aren't convinced writing a class instead of mocking does much to improve the problems 
mentioned above, I don't blame you. The real power in writing a class is that it is _whole_: a 
_whole idea_. It's not just a collection of delicately specific stubs, but a persistent, evolvable 
and cohesive implementation devoted to the problem of testing.

When all you need is a few stubbed methods, mocking libraries are great! **But the convenience of 
these libraries has made us forget that we can often do much better than a few stubbed methods.** 
Like aimlessly adding getters and setters, we have forgotten the whole point of object-oriented 
programming is that objects are useful, cohesive abstractions. No wonder OOP gets so much flak.

Consider that test setup often has a higher order semantic meaning mock DSLs end up obfuscating. 
When we stub an external service call like 
`when(creditService.checkCredit(eq(AccountId.of(1)))).thenReturn(HOLD)`, what we are saying is, 
"Account 1 is on credit hold." Rather than reading and writing a mock DSL that speaks in terms of 
methods and arguments and returning things, we can _name_ this whole concept as a method itself, as 
in `creditService.placeHoldOn(AccountId.of(1))`. Now this concept is reified for all developers to 
reuse (including your future self). *This is encapsulation*: giving a name to some procedure or 
concept. It builds the [ubiquitous language][ubiquitous-language] for your team and your tools. Have
some other procedure or concept that comes up while testing? Now you have a place you can name it 
and reuse it later: a class! I find myself adding and using methods like these constantly in my 
tests, and it is incredibly productive. A mock can't do this, because it only works within the 
confines of an existing production interface.

Above, we discussed that classes save you from reimplementing a contract for many tests. More than
that, however, they make implementing those contracts simpler in the first place. Need a place for 
persistent state within the type? Well, now you have fields of course. It's easy to take for granted
all the humble class can do for us.

[dont-spy]: https://javadoc.io/doc/org.mockito/mockito-core/latest/org/mockito/Mockito.html#13
[dont-overuse-mocks]: https://testing.googleblog.com/2013/05/testing-on-toilet-dont-overuse-mocks.html
[mocks-are-stupid]: https://www.endoflineblog.com/testing-with-doubles-or-why-mocks-are-stupid-part-4#2-mocks-are-stupid-and-so-are-stubs-
[ubiquitous-language]: https://martinfowler.com/bliki/UbiquitousLanguage.html

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
