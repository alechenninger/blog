<meta name="labels" content="">
<meta name="title" content="Mockito Considered Harmful, or How I Learned To Stay Calm and Stop Mocking">
<meta name="description" content="">

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
        clear that mocking classes is a bad idea, it seems many developers never read it.
* alternative
    * use the classes you already have.
        * separate business logic from infrastructure (see DDD)
        * business logic classes should never be stubbed or faked or mocked. this is why they should
        also never have interfaces–there is only one correct implementation by definition.
    * wrap infrastructure and external dependencies in interfaces; write in memory fakes.
        * repository pattern
        * anti-corruption layer
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
        
            
      
      

