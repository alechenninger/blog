<meta name="id" content="6165535919949189914">
<meta name="labels" content="go,programming languages">
<meta name="title" content="Go Distilled">
<meta name="description" content="A terse guide for beginners in go to writing and organizing idiomatic go code for non-trivial programs.">

Go (or "golang") is a [loosely object-oriented](https://golang.org/doc/faq#Is_Go_an_object-oriented_language), natively compiled language biased towards C-like simplicity, speed, and network applications. Its original authors, in a reaction to C++'s ever-growing feature set, created Go from the philosophy that ["less is more"](https://commandcenter.blogspot.com/2012/06/less-is-exponentially-more.html). Pragmatic and productive for large teams, it emphasises fast compile times and simple but productive abstractions like garbage collection, [structural typing](https://en.wikipedia.org/wiki/Structural_type_system), and namesake first class support for concurrent functions, {goroutines}.

Getting started with Go typically involves...

* An [interactive language tour]() (recommended)
* Reading [How to Write Code in Go]()
* Reading [Effective Go]()

This aims to cover that material (I'll often quote it) and more, as tersely as possible, to get you productive in Go, quickly. We'll start with a quick demonstration of the basics, and then move to a practical, real-world guide to starting and contributing to real Go programs.

## A quick tour of the basic syntax

C family. Types inferred. Use tabs not spaces. Redundant symbols are often optional like parentheses in for loops, or semicolons. A few built-in features like collections or channels or type switches have special syntax. No line length limit, but be reasonable. Built-in auto-formatter, because we are not barbarians, after all.

// If you want to explore the syntax with an interactive editor, check out the [official language tour](https://tour.golang.org/).

### Comments, documentation, variables, and assignments

Comments that immediately precede top-level declarations which be included in generated documentation (via [godoc](https://blog.golang.org/godoc)). Others will not.

// Beginning this post with how to write good documentation was no accident!

Documentation comments have simple syntax. Mostly, just write plain text markup:

* For code blocks (or other preformatted text), indent those lines.
* Links will automatically create hyperlinks.
* Headings are lone lines that start with capital letter, precede a paragraph, and contain no punctuation other than parentheses or commas 
* Example code has [first class support](https://golang.org/pkg/testing/#hdr-Examples) in godoc, but understanding how that works requires a bit more understanding about package layout and testing, so we'll come back to this below `TODO add link`.

```go
// Not included in documentation (does not precede a declaration).

// This comment is documentation.
//
// Heading
//
// This is a paragraph under that heading.
//
//     // Indent code like you would in markdown.
var x int = 1 
```

Above and below show variables with an **explicitly declared type and initializer**. This is **uncommon** unless the inferred type would be inappropriate.

```go
// Would infer int, but x is a float32 because we explicitly said so.
var x float32 = 1
```

**Variables may be uninitialized**: simply omit the equals and value. **Uninitialized variables start with a [{{zero value}}](https://golang.org/ref/spec#The_zero_value)**. For basic types the zero value is generally what you might expect, particularly if you are coming from Java: numeric types get 0, booleans get false, strings get the empty string.

```go
var x int // initialized to 0.
```

As alluded to above, **if you have an initial value, the type can be inferred**. In this case, it's common to use the {{short assignment}} syntax shown below, but this only works inside functions, because [top-level declarations must start with a keyword](https://groups.google.com/forum/#!msg/golang-nuts/qTZemuGDV6o/IyCwXPJsUFIJ). For top-level declarations, you can still omit the type, you just have to keep `var`.

```go
// Short assignment, not usable outside functions
x := 1

// Starts with keyword, so usable top-level; prefer short assignment inside functions
var y = 2
```

You may also **declare multiple variables together**, which is useful for grouping related variables, since, other than
obviously appearing together inside parenthesis, [doc comments apply to the entire group as a unit](https://golang.org/doc/effective_go.html#commentary).

```go
// Doc comments on grouped variable declarations document the whole group as a unit.
var (
    ErrInternal      = errors.New("regexp: internal error")
    ErrUnmatchedLpar = errors.New("regexp: unmatched '('")
    ErrUnmatchedRpar = errors.New("regexp: unmatched ')'")
)
```

Another way to declare multiple variables at once is to **list them comma delimited.** In this case however the variables **must share the same type, or all use inferred types**.

```go
var x, y = 1, 2

// Short assignment works inside functions as above
x, y := 1, 2

// Explicit type works too if needed
var a, b string = "a", "b"
```

As we'll see shortly, functions may return multiple values. In that case, you'll use the comma delimited syntax above to assign each value.

```go
results, err := search("go distilled")
```

### Basic types

The following snippet demonstrates the basic types in go.

```go
var funLanguage bool = true
var itIsUtf8 string = "こんにちは"
var sizedBasedOnPlatform int = 1
var explicitSize int32 = 2
var unsigned uint = 3
var bitsAndBytes byte = 0
var floatingPoint float32 = 1.234
```

Numeric type bit widths may be 8, 16, 32, or 64. Just use the default (e.g. `int`) unless you have a good reason otherwise.

### Functions

As in variables, **types follow names**. This function, named "greeting", accepts a string named "who" and returns a string.

```go
func greeting(who string) string {
    return "Hello, " + who + "!"
}
```

As mentioned above, **functions may return multiple values**, often used for error handling, since go does not have traditional exceptions like Java or Python. (See introductory points on minimalism.)

```go
func greeting(who string) (string, int) {
    return "Hello", len([]rune(who))
}
```

**Return values may also be named**. Sometimes this makes their intent clear.

```go
func greeting(who string) (greeting string, whoLength int) {
    return "Hello", len([]rune(who))
}
```

**Named return variables can actually be assigned by name**, and returned via a {{naked 
return}}. This is occasionally useful in short functions, as in this example from 
[Effective Go](https://golang.org/doc/effective_go.html#named-results). **Not recommended in longer functions** for obvious reasons.

```go
func ReadFull(r Reader, buf []byte) (n int, err error) {
    for len(buf) > 0 && err == nil {
        var nr int
        nr, err = r.Read(buf)
        n += nr
        buf = buf[nr:]
    }
    return
}
```

### Collections

#### Arrays and slices (lists)



#### Maps

### Flow control

```go

```

### Pointers

## Concurrency

* goroutines
* channels
* shared memory semantics
* context passing

## Go in practice

### Object-oriented Go

* Type definitions
* Structs – note documenting structs (whole struct appears in docs), good zero types


// For a more advanced understanding of how to use the zero value effectively, see [What is the zero value, and why is it useful?](https://dave.cheney.net/2013/01/19/what-is-the-zero-value-and-why-is-it-useful)

* Interfaces
* Methods (extension methods)
* Casts

### Organization: modules, packages, visibility, and repository layout




### Enums and `iota`

https://github.com/golang/go/wiki/Iota



