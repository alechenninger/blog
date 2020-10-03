<meta name="id" content="5059786785061561365">
<meta name="labels" content="testing,object oriented programming">
<meta name="title" content="Keep Calm and Stop Mocking">
<meta name="description" content="">

Mockito (with the help of its dependencies) is an amazing feat of engineering: a super readable, 
runtime meta-programming DSL that is simultaneously implemented in the very type system that it
bends and breaks. Mockito has helped 1000s of developers test their code. It is among the [most 
popular Java libraries ever](https://docs.google.com/spreadsheets/u/0/d/1aMNDdk2A-AyhpPBnOc6Ki4kzs3YIJToOADeGjCrrPCo).

What if this isn't actually a good thing?

I was once a frequent Mockito user, perhaps like you are now. Over time however, as my application 
architectures improved, as I began to introduce real domain models, the tests I wrote were becoming 
simpler, easier to add, and services easier to develop. Tricky testing problems that loomed over my 
head for years now had obvious solutions. Much to my surprise, I was barely using Mockito at all.

Consider Mockito may be too good at what it does. Like habitual scrolling through endless social 
media and news feeds, we have found ourselves using it all the time to our own detriment. What 
happened? What could such a well-engineered, much loved library possibly be doing that is bad for 
us?

In this post, I demonstrate some compelling and, in my experience, overlooked advantages to mock 
alternatives. We will explore the origins of mocking, why mocking may have become so ubiquitous, a 
world without mocking, and the system of incentives, practices, and abstractions that evolve as a 
result. Whether you are a casual or devout mock-ist, I encourage you to keep calm, open your mind, 
and try going without for a while. This post will guide you. You may be surprised what you find, as 
I was.

// Likewise, if you find your projects suffer without mocking, I'd love to hear about it!

## Mocking 101

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

We'll come back to this.

## Why we mock

Of course, I'm mostly lying. The defining feature of mocking libraries is that those implementations
_aren't_ totally equivalent: mocks (and their peers, spies) _record_ their method calls so you may 
assert on not just the state of your program, but the _means_ of your program. That is, the state of
_interactions_ between objects, like what methods were called, how many times, with what arguments, 
and in what order.

While that is a [mock's true purpose](
https://martinfowler.com/articles/mocksArentStubs.html#TheDifferenceBetweenMocksAndStubs), mocking
libraries are also often used to implement types at runtime, regardless of method verification, as 
described above. This magical runtime-type-implementing DSL sometimes feels more _convenient_ than 
the native Java approach, such as when you have a large interface to stub. You can simply not 
implement some methods, and instead of a compilation error, you get a default, no-op implementation.
Some mock libraries even let you accomplish scandalous mischief like reimplementing final classes or
enums or static methods. I broadly classify these as convenience features, because they save you 
time by "saving" you from writing a whole class that implements some interface, or refactoring your 
code so that it may be testable by language-supported means. It "saves" you from answering that 
pesky question, "How do I test this?" Every time, the answer is a mock! It's just so easy, after 
all. 

## A Whole Class

When a class under test has a mocked dependency, the dependency must be stubbed.

// Of course, unless you use a spy. But, you're not really supposed to use those. Just [ask 
Mockito's authors](https://javadoc.io/doc/org.mockito/mockito-core/latest/org/mockito/Mockito.html#13)
.

We don't want to bother stubbing all the methods out, so we only stub the ones our test needs. 
Similarly, we don't want to implement state or much logic, so just implement them method say for
certain arguments, and return some result. Again, the arguments and result are what our test needs.

The first time you do this, for a handful of tests, it is magical. So productive. Once we start to
add a lot more tests, and our class or dependency evolves over time, a couple things happen.

First of all, our tests are relying on the implementing of our class in subtle ways. They /know/
what methods to stub, and how. If our implementation changes, we may need to update our tests, 
even though they are still testing the same scenario. Each time we write a new test, we must recall
how the dependency is used, so we stub it the right way.

// TODO: example

Secondly, tests are repeating the contract of the dependency. As the dependency changes, all of your
tests must update. Likewise, as we add more tests, we must again recall how the dependency works,
so we stub it the right way.

You may argue, "Well just refactor the test setup to be done once in one `@BeforeEach` method
for the whole class." Except, what about the next test class? What about tests that need

* mocks force test setup to repeat knowledge of the implementation of unit-under-test in *how it
uses* a collaborator and how that collaborators interface works. test setup often has a higher order
meaning, and we might like to name this. OOP gives us a first class means for capturing a reusable
operation and giving it a name: a method. but mocking doesn't let us add new methods, because we 
work with an existing interface.
* other times, the existing interface might be fine, but the methods have contracts between each 
other that collaborators might depend on, so your mocking gets complex. instead of each test doing
complex mocking, maybe you abstract that out to a reusable mock. now you have a reused method that
configures a new type using a runtime dsl that defines the behavior of methods at runtime. take a 
step back a second – why again wouldn't you write a class instead?  
* alternative to mock is often a fake
* a fake is a demonstration of how a type should behave – it is documentation for our team
* reuse in other tests
    * verify captures contract
    * what about when you want to reuse knowledge of that contract?
    * write methods that create mocks again and again the same way, or verify the same way
    * compare this to writing a class that captures the contract
* codify domain knowledge in set up

## Hermetic servers

* fakes can be used outside of src/test for variety of valuable use cases
* help yourself test / experience a service locally
* help other teams test
* load test a service isolating certain dependencies

## The futility of isolation

We humans are innately obsessed with organizing our thoughts and concepts with ontologies and 
taxonomies and hierarchies. [Sorting just makes us feel like we're doing something *good* and 
*productive*.](https://originalcontentbooks.com/blog/organize-things-to-get-more-done) I feel all 
cozy inside just thinking about it.

Are you daydreaming about the deep, artful hierarchy of subpackages in your Java code now, hmmm?

"Unit" tests, in the ontology of testing, isolate a unit of code to ensure it functions correctly.
We often contrast these with "integration" tests, which test these units together, without 
isolation. We heard writing lots of unit tests is good, because of something about a [pyramid and 
an ice cream](https://docs.google.com/presentation/d/15gNk21rjer3xo-b1ZqyQVGebOp_aPvHU3YH7YnOMxtE/edit#slide=id.g437663ce1_53_98) 
cone, so we have to make sure most of our tests only use isolated units, so that most of our tests
are unit tests.

"Unit" is intentionally though unfortunately ambiguous, which means naturally, over time, it 
devolved. In object-oriented programming's case, it became "class" or "method", and so we became 
hyperfocused on isolating a class or method under test from all others.

Let's back up–why are we replacing collaborators with fakes or mocks or stubs or whatever in the
first place?

* rarity of a domain model
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



## `popularity(x) != value(x, context)`

## When to Mockito

* mockito's own documentation is littered with warnings of when not to use its features
* legacy code
* one-off, simple stubs

## Closing thoughts



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
        
            
      
      

