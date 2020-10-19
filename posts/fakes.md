<meta name="labels" content="testing,object oriented programming,java">
<meta name="title" content="Fake it 'til you make it">
<meta name="description" content="">

Much has been said about mocks, the controversial, swiss-army knife of test doubles. Mocking has
become so ubiquitous due to the popularity and flexibility of mocking libraries like mockito, [one
of the most popular Java libraries in the world][m]. Libraries like mockito make it so easy to make
a simple mock or stub, that I find we forget their older and wiser cousin, the humble "fake." 
{Fakes} are "objects [that] actually have working implementations, but usually take some shortcut 
which makes them not suitable for production (an in memory database is a good example)."^[1]   

older and wiser cousin, the humble fake? 

---

^1: For this and other definitions of test doubles like stubs and fakes, see Martin Fowler's 
[Mocks Aren't Stubs][mas].

[m]: https://docs.google.com/spreadsheets/u/0/d/1aMNDdk2A-AyhpPBnOc6Ki4kzs3YIJToOADeGjCrrPCo
[mas]: https://martinfowler.com/articles/mocksArentStubs.html

---

Mockito (with the help of its dependencies) is an amazing feat of engineering: a super readable, 
runtime meta-programming DSL that is simultaneously implemented in the very type system that it
bends and breaks. Mockito has helped 1000s of developers test their code. It is among the [most 
popular Java libraries ever](https://docs.google.com/spreadsheets/u/0/d/1aMNDdk2A-AyhpPBnOc6Ki4kzs3YIJToOADeGjCrrPCo).

What if this isn't actually a good thing?

I was once a frequent Mockito user, perhaps like you are now. Over time however, as my application 
architectures improved, as I began to introduce 
[real domain models](http://qala.io/blog/anaemic-architecture-enemy-of-testing.html), the tests I 
wrote were becoming simpler, easier to add, and services easier to develop. Tricky testing problems 
that loomed over my head for years now had obvious solutions. Much to my surprise, I was barely 
using Mockito at all.

Consider Mockito may be too good at what it does. Like habitual scrolling through endless social 
media and news feeds, we have found ourselves using it all the time to our own detriment. What 
happened? What could such a well-engineered, much loved library possibly be doing that is bad for 
us?

In this post, I demonstrate some compelling and, in my experience, overlooked advantages to mock 
alternatives. We will explore the origins of mocking, why mocking may have become so ubiquitous, a 
world without mocking, and the system of incentives, practices, and abstractions that evolve as a 
result. Whether you are a casual or devout mock-ist, I encourage you to keep calm, open your mind, 
and try going without for a while. This post will guide you. You may be surprised what you find.

// Likewise, if you find your projects suffer without mocking, I'd love to hear about it!

## Why we mock

Mockito is a mocking library, but let's respect that for what it is: meta-programming. Mocking is 
using a library's own types, to implement new types, at runtime, in a language where you can 
natively implement types at compile-time. These two examples are basically equivalent:

```java
Foo stubFoo = new Foo() {
  String bar() { return "bar"; }
};
```

versus...

```java
Foo mockFoo = mock(Foo.class);
when(mockFoo.bar()).thenReturn("bar");
```

Why bother using complex reflection and low-level bytecode acrobatics to write a class when we can, 
you know, simply _write a class_ using basic, tool-supported, first-class language features?

In the above example, aside from astonishingly greater implementation complexity, the Mockito 
version actually requires _more_ characters (a lot more if you rewrote the stub as a lambda).

## Why we actually mock

Of course, I'm mostly lying. The defining feature of mocking libraries is that those implementations
_aren't_ totally equivalent: mocks (and their peers, spies) _record_ their method calls so you may 
assert on not just the state of your program, but the _means_ of your program. That is, the state of
_interactions_ between objects, like what methods were called, how many times, with what arguments, 
and in what order.

While that is a [mock's true purpose](
https://martinfowler.com/articles/mocksArentStubs.html#TheDifferenceBetweenMocksAndStubs), mocking
libraries are also often used to implement types at runtime, regardless of method verification, as 
described above. This magical runtime-type-implementing DSL often feels more _convenient_ than the 
native Java approach, such as when you have a large interface to stub. You can simply not implement 
some methods, and instead of a compilation error, you get a default, no-op implementation. When 
implementing a stub, you can directly map known input-output pairs by only stubbing a method for 
particular arguments (as opposed to writing several conditional expressions). Some mock libraries 
even let you accomplish scandalous mischief like reimplementing final classes or enums or static 
methods. I broadly classify these as convenience features, because they save you time by "saving" 
you from writing a whole class that implements some interface, or refactoring your code so that it 
may be testable by language-supported means. It "saves" you from answering that pesky question, "How
do I test this?" Every time, the answer is a mock!

## A Whole Class

When a class under test has a mocked dependency, the dependency must be stubbed according to the 
needs of your test.

// Of course, unless you use a spy. But, you're not really supposed to use those. Just [ask 
Mockito's authors](https://javadoc.io/doc/org.mockito/mockito-core/latest/org/mockito/Mockito.html#13).

We don't want to bother stubbing all the methods out, so we only stub the ones our test needs. 
Similarly, we don't want to implement state or much logic, so just implement the method say for
certain arguments, and return some result.

The first time you do this, for a handful of tests, it is magical and productive. Once we start to
add a lot more tests, or our classes or dependencies evolves over time, a couple of things happen.

First of all, in this short-hand stubbing pattern, our tests are [relying on the implementation of 
our class](https://testing.googleblog.com/2013/05/testing-on-toilet-dont-overuse-mocks.html) in 
subtle ways. By leaving out stubbing some methods, we imply we know _what_ methods are used. By only
stubbing for certain arguments, we imply we know _how_ those methods are used. If our implementation
changes, we may need to update our tests, even though they are still testing the same scenario.
Likewise, each time we write a new test, we must recall how the dependency is used, so we stub it
the right way.

// TODO: example

Secondly, tests are repeating the contract of the dependency. That is, as the dependency changes, 
any tests stubbing it may need to update to conform to its updated contract. Likewise, as we add 
more tests, we must again recall how the dependency works, so we stub it the right way. For example,
if an interface encapsulates some state between subsequent method calls, or a method has some
preconditions or postconditions, and [your stub does not reimplement these 
correctly](https://www.endoflineblog.com/testing-with-doubles-or-why-mocks-are-stupid-part-4#2-mocks-are-stupid-and-so-are-stubs-), 
your tests may pass even though the system-under-test is not correct (or vice versa).

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
concept. It builds the [ubiquitous language](https://martinfowler.com/bliki/UbiquitousLanguage.html)
for your team and your tools. Have some other procedure or concept that comes up while testing? Now 
you have a place you can name it and reuse it later: a class! I find myself adding and using methods 
like these constantly in my tests, and it is incredibly productive. A mock can't do this, because it 
only works within the confines of an existing production interface.

Above, we discussed that classes save you from reimplementing a contract for many tests. More than
that, however, they make implementing those contracts simpler in the first place. Need a place for 
persistent state within the type? Well, now you have fields of course. It's easy to take for granted
all the humble class can do for us.

## Fakes and hermetic servers

What we're discussing here so far is actually closer to a 
[{fake}](https://martinfowler.com/articles/mocksArentStubs.html#TheDifferenceBetweenMocksAndStubs) 
than a {stub}. A fake is a complete reimplementation of some interface suitable for testing. As 
we've described, fakes are often very useful, and deserve a priority slot in our testing toolkit; 
slots too often monopolized by mocks.

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

Yet we have still only scratched the surface. As the software industry is increasingly concerned
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

## The futility of isolation

We humans are innately preoccupied with organizing our thoughts and concepts with ontologies and 
taxonomies. [Sorting just makes us feel like we're doing something *good* and 
*productive*.](https://originalcontentbooks.com/blog/organize-things-to-get-more-done) I feel all 
cozy inside just thinking about it.

Perhaps you a recall of tinge of satisfaction when you've added yet another subpackage inside your 
Java project?

"Unit" tests–sometimes called "component" tests–in the ontology of testing, isolate a unit of code
to ensure it functions correctly. We often contrast these with "integration" tests (confusingly, 
sometimes also called component tests), which test units together, without isolation. We heard 
writing lots of unit tests is good, because of something about a 
[pyramid and an ice cream cone](https://docs.google.com/presentation/d/15gNk21rjer3xo-b1ZqyQVGebOp_aPvHU3YH7YnOMxtE/edit#slide=id.g437663ce1_53_98),
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

So let's back up. We've been talking a lot about replacing dependencies with mocks or stubs or fakes. 
Why are we replacing dependencies in the first place?

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
converge at the same reason. It is the reason we write tests in the first place: to ship more value,
more quickly (after all, 
[features which improve safety also improve speed](https://www.heavybit.com/library/podcasts/o11ycast/ep-23-beyond-ops-with-erwin-van-der-koogh-of-linc/)).
Crucially, replacing collaborators with test doubles has an effect directly counter to this end 
goal: _those replacements aren't what we actually ship_. If you go too far with mocking, what 
actually happens is that your feedback cycles _slow way down_ because you aren't actually seeing 
your code as it truly works until you deploy and get it in front of users.

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

## Isolate by abstractionn

* anti-corruptionn layer

## Testable code


## When to Mockito

* mockito's own documentation is littered with warnings of when not to use its features
* legacy code
* one-off, simple stubs

## Closing thoughts

* Mostly, tools are not bad or good. We must remember to use them with intention. 
* Reuse your existing, well-tested implementations where you can. Strive to make your classes
reusable in tests. Never stub or fake business logic.
* Start tests from your core types and work outward, focusing on the testing the contract of the 
class under test. Don't worry if the tests are somehow redundant with other tests–that's a matter
of implementation. What matters is the class, in conjunction with obedient collaborators, implements
its own contract.
* When using the real thing is harmful (such as too complex to set up, which often also means the 
tests would run too slowly), ensure you've first isolated through abstraction. Then, fake the 
abstraction. Write tests that run against both the fake and the real implementation to ensure the
fake is compliant.
* Capture common set up scenarios in the language of your problem domain as methods on your fakes.
* Compile your fakes with your program, and put them behind configuration flags or profiles to 
enable lightweight modes of execution.


---

Old material:

// I've only scratched the surface. Other testing types include 
["integrated" tests](https://blog.thecodewhisperer.com/permalink/integrated-tests-are-a-scam) (yes, 
not to be confused with "integration" tests), "component" tests, "end-to-end" tests, "service" 
tests, "system" tests, "contract" tests, ... I'm sure I've missed some. Part of the problem is these
types describe 
[orthogonal dimensions of testing](http://qala.io/blog/holes-in-test-terminology.html). Perhaps, 
though, the Google approach is the least problematic simplification: 
[small, medium, and large](https://testing.googleblog.com/2010/12/test-sizes.html).

## Asserting on program state vs object interactions

> This section is probably unnecessary / not very interesting

First, an absurd question:

What is the point of our programs: to solve problems, or to call methods?

Now, let's consider a scenario we must test:

```
Given an order for a subscription
When the order is fulfilled
Then the account named on the order has one active subscription
```

Compare these two tests:

```java
var subscriptions = new InMemorySubscriptions();
var orderService = new OrderService(subscriptions);

orderService.receive(new Order(new Subscription(), new AccountId(1)))

assertThat(
    subscriptions.activeSubscriptionsIn(new AccountId(1)))
    .containsOnly(new Subscription()))
```

```java
var subscriptions = mock(SubscriptionService.class);
var orderService = new OrderService(subscriptions);

orderService.receive(new Order(new Subscription(), new AccountId(1)))

verify(subscriptions).entitleAccount(new Subscription(), new AccountId(1));
```

There is a subtle but important difference in the language here: is the point of the test 



## NOTES

another outline:

* when you want to define an implementation of a type, java gives you a Class. Mockito gives you
a meta-programming DSL for defining an implementation of a type.
* why have a meta-programming DSL implemented in the same language that already has support for the
what the meta-programming DSL is doing?
    * sometimes, in the short run, the meta-programming DSL uses less code
    * the meta-programming DSL is more powerful and can do things the java type system doesn't let 
    you do, like reimplementing final classes, at the cost of fantastical complexity and baffling
    edge cases.
    * the meta-programming DSL let's you /verify/ methods were called–the defining feature of a 
    true _mock_
* but when do you actually need those things? are those really good ideas?
    * verifying behavior over state has several issues (see below)
    * doing things the java type system doesn't let you do is abused to avoid writing code that is
    testable to begin with.
    * does it really save you code in the long run?
* did we stop to consider the advantages of the "plain old java" way?
    * classes are trivial to reuse
    * classes are easier to understand when multiple methods are stubbed or there is interaction 
    between methods
    * classes make it easy to track state
    * classes can _encapsulate_ behavior behind a _name_, enriching your teams use of business 
    language and sharing knowledge
    * classes can easily be tested when they get complex
    * classes encourage understanding your model and writing testable code
* what is testable code and why does it matter?
    * testable code
* saving code
    * mockito stubs are cumbersome to reuse. they shine when they aren't reused.
* why is mockito so popular?
    * in the short run, it is quicker.
        * initially, it uses less syntax
        * you don't have to think about your src/main code since you can replace any interface or
        type regardless.
    * its popularity is also self-serving, the more popular it is, the more integration it gets, 
    the more examples it appears in, and thus the more popular it gets, so the more integrations it
    gets, and the more examples it appears in, and so on.
    * it's great for examples because examples need code that is very terse in the short-run. 
* mockito is primarily a niche tool for performing reflection and byte-code acrobatics for hacking 
testability into legacy or third party code that would be otherwise impractical to refactor. 
somewhere along the line, it became the default tool for every dependency in a test. stay calm, and
stop mocking.

outline (brain dump):

* intro
    * amazing library by talented people
    * but incentivizes poor practices
* problems
    * mocks aren't stubs: https://martinfowler.com/articles/mocksArentStubs.html
        * encourages everything to be a "mock" (this is kind of similar to overuse point below)
        * im not even sure people think of or remember that there are other choices
        * in an extreme case of this, i have seen cases where, given repeating the same "mock" 
        (actually, stubbing) set up many times, the "mocking" code was pulled out to shared methods.
        these methods ultimately configuring complex stubs. you know what is another way to 
        configure a stub? A Class! Mockito is a meta-language inside Java for simply defining a 
        class... something Java can obviously already do as a first class citizen. 
         
          ```
          class StubFoo implements Foo {
              String bar() { return "bar"; }
          }  
          ```
          
          vs
          
          ```
          Foo mockFoo = mock(Foo.class);
          when(mockFoo.bar()).thenReturn("bar")
          ```
          
          For the occasion quick stub, the mockito DSL is great. But for reused stubs or complex 
          logic inside stubs... the mockito implementations quickly escalate past sanity compared
          to the obvious class.
    * overuse
        * https://testing.googleblog.com/2013/05/testing-on-toilet-dont-overuse-mocks.html
        * mocking is so easy its often used when entirely unnecessary. for example, if we have a 
        class that depends on another class, we may mock that dependency reflexively. but what if
        there is business logic in that dependency? now we have to make sure our mock object stays
        true to that contract–repeating it–or our tests are invalid by definition. often these 
        dependencies need not be heavy or may not even have any other dependencies at all!
        * all tests are integration tests.
            * https://www.facebook.com/notes/kent-beck/unit-tests/1726369154062608/
            * https://testing.googleblog.com/2010/12/test-sizes.html
            * sometimes developers think, "well this is a *unit* test, so i can't test anything 
            else. mock the rest!" no class exists in isolation. you are always depending on 
            something. yes you are testing a unit, but you are also testing that units *collaboration*
            with other code. yes that other code will be "tested." we expect that code to behave 
            correctly, so we don't need to focus on its contract, only the contract and edge cases
            of our class under test. the other code has its own tests! but that doesnt mean we have
            to for some reason _avoid_ using any other code. not only is there no reason to, its both
            impossible and actively harmful. all code uses other code. you don't try to mock 
            ArrayList, do you? similarly, if you replace that code, you will simply be replacing it
            with... more code. code you will write quickly, and that won't have its own tests, and
            so we have no idea if it actually supports the contract of the collaborator.
            * why are we so obsessed with isolation if we trust our collaborators? https://easymock.org/
        * mocking complex protocols like HTTP interactions is fraught with error
            * https://testing.googleblog.com/2018/11/testing-on-toilet-exercise-service-call.html
            
        * thought terminating
    * lack of reuse
        * mocks need to be restubbed often. 
        * if you try to extract them out, you end up with a barbaric meta-language of defining a 
        class described above. the way to define a reusable implementation is called a "class".
        * this lack of reuse means that common knowledge doesn't get codified. the behavior we 
        expect, the common scenarios we set up, in the language of the domain. other members can 
        only see that by looking at and copy other tests, and they will be in the domain of 
        meta-programming, not your business. when compared with a fake, the API documents a shared 
        understanding, and lets developers expand that understanding with their own.
    * false sense of security / behavior doesn't matter... only state.
        * i have seen a test with `foo.bar(); verify(foo).bar();` the mock equivalent of `assertTrue(true)`
        * https://testing.googleblog.com/2013/03/testing-on-toilet-testing-state-vs.html
            * Even in some examples of interaction testing here could be modeled as state changes.
            For example, for checking sent mail, a stub or fake could be implemented which tracks
            the state of sent mail. Assertions can check that state does not include duplicates.
        * testing of–and thus, coupling to–implementation detail instead of what matters.
            * https://testing.googleblog.com/2015/01/testing-on-toilet-change-detector-tests.html
    * does not encourage testable code
        * you can mock or spy classes as well as interfaces. while mockito's documentation is quite
        clear that mocking classes in most cases is a bad idea, it seems many developers never read 
        it.
            * https://javadoc.io/doc/org.mockito/mockito-core/latest/org/mockito/Mockito.html#13
            * https://javadoc.io/doc/org.mockito/mockito-core/latest/org/mockito/Mockito.html#16
            * https://github.com/mockito/mockito/wiki/Using-Spies-%28and-Fakes%29#invariants-and-state
            
* alternative
    * use the classes you already have.
        * separate business logic from infrastructure (see DDD)
        * business logic classes should never be stubbed or faked or mocked. this is why they should
        also never have interfaces–there is only one correct implementation by definition.
    * wrap infrastructure and external dependencies in interfaces; write in memory fakes.
        * repository pattern
        * anti-corruption layer
            * dependencies too complex to fake? 
                * wrap them in a simpler interface (anti-corruption layer)
                * test the production implementation once
                * test the fake implementation once
                * use the fake inside all of your tests
        * these are reuseable for other tests
        * there are even reusable in src/main!
            * https://testing.googleblog.com/2012/10/hermetic-servers.html
            * enable other teams to test using your service in "in-memory" mode, which starts up
            with zero network dependencies.
            * load test parts of your system without load testing all of your dependencies: use
            in-memory fakes for one or more of them.
        * write contract tests which run against both production impls and in memory impls
        * https://testing.googleblog.com/2013/06/testing-on-toilet-fake-your-way-to.html
        * add common useful set up and state examination methods to fakes
        * libraries for in memory repositories:
            * for sql, h2
            * for document stores, nitrite, or write your own (see https://github.com/alechenninger/memorize)
        * the work required to write these is instructive. you are forced to understand your domain
        and collaborations with other objects. you are forced to understand your queries.
    * test by asserting state, not behavior
        * add necessary state retrieval methods to your fakes where needed.
* conclusion
    * i never intended to stop using mock objects all together, but once i stopped, i never looked
    back. try using fakes for a little while instead.
        
            
      
      

