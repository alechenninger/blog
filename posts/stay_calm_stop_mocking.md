<meta name="id" content="5059786785061561365">
<meta name="labels" content="testing,object oriented programming">
<meta name="title" content="Mockito Considered Harmful (or, How I Learned To Stay Calm and Stop Mocking)">
<meta name="description" content="">

Mockito (with the help of its dependencies) is an amazing feat of engineering: a super readable, 
runtime meta-programming DSL that is simultaneously implemented in the very type system that it
bends and breaks. Mockito has helped 1000s of developers test their code. It is among the most 
popular Java libraries ever.

What if this isn't actually a good thing?

Mockito is too good at what it does. Like habitual scrolling through endless social media and news 
feeds, we have found ourselves using it all the time to our own detriment.

What happened? What is Mockito doing that is so bad for us?

## What does Mockito actually do?

Mockito is a mocking library, but let's call that what it is: meta-programming. Mocking is 
using its own types, to implement new types at runtime, in a language where you can natively 
implement types at compile-time. These two examples are basically equivalent:

```java
Foo stubFoo = new Foo() {
  String bar() { return "bar"; }
};
```

vs.

```java
Foo mockFoo = mock(Foo.class);
when(mockFoo.bar()).thenReturn("bar");
```

Why would we invest so much time an energy in complex reflection and low-level bytecode acrobatics 
to write a class when we can, you know, simply _write a class_?

In the above example, aside from astonishingly greater implementation complexity, the Mockito 
version actually requires _more_ characters. 

Of course, the defining feature of a mocking library is that that implementation isn't all there is 
to it: mocks _record_ their method calls so you may assert on not just the state of your program, 
but the _means_ of your program. That is, the state of _interactions_ between objects, like what 
methods were called, how many times, with what arguments, and in what order.

## Asserting on program state vs object interactions

First, an absurd question:

What is the point of our programs: to solve problems, or to call methods?

Now, let's consider a scenario we must test:

```
Given an account
When an order is received for a subscription for the account
```

Compare these two tests:

```java
var subscriptions = new InMemorySubscriptions();
var orderService = new OrderService(subscriptions);

orderService.receive(new Order(new Subscription(), new AccountId(1)))

assertThat(subscriptions.activeSubscriptionsIn(new AccountId(1))).containsOnly(new Subscription()))
```

```java
var subscriptions = mock(SubscriptionService.class);
var orderService = new OrderService(subscriptions);

orderService.receive(new Order(new Subscription(), new AccountId(1)))

verify(subscriptions).entitleAccount(new Subscription(), new AccountId(1));
```

## What's in a type, anyway?


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
        
            
      
      

