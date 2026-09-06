# MulleBashStringExpansion Library Documentation for AI
<!-- Keywords: Objective-C, bash, expansion, string, substitution, template, keypath -->

## 1. Introduction & Purpose

**MulleBashStringExpansion** provides Bash-like string expansion for Objective-C
`NSString`. It implements a subset of the Bash shell's *parameter expansion*
(see the GNU Bash Manual, section 3.5.3 "Shell Parameter Expansion"), so that
strings like `"${foo:-bar}"`, `"${path##*/}"` or `"${url//http:/https:}"` can be
expanded against a data source (a dictionary or any object supporting keypath
lookup).

It is used by template engines such as **MulleScion** and is useful for:
- Template rendering with variable substitution
- Configuration file processing with dynamic values
- Conditional defaults, substrings, prefix/suffix removal, replacement
- Case transformation (uppercase/lowercase)

Explicitly **not** supported: command substitution `$()`, arithmetic expansion
`$(())`, backticks, tilde expansion, globbing, and quoted strings. Backslash
escape sequences *are* honored.

The `S` class is a companion class (do not confuse with a "string" type) that
wraps both plain string operations (range, replace) and bash expansion behind
selector-heavy convenience methods, designed for use inside MulleScion
templates.

## 2. Key Concepts & Design Philosophy

- **Bash compatibility subset:** implements the common `${parameter}` operators
  from the Bash manual, but restricted to a well-defined set (see 3.5).
- **Data source (`info`):** expansion looks up variable values through
  `valueForKeyPath` on the `info` object. For dictionaries this supports key
  paths (dotted names like `"foo.bar"`). Values are converted with
  `description`; missing values become the empty string `""`.
- **Locals + data source precedence:** the `S` class consults its `locals`
  dictionary first and falls back to the `dataSource` if the key is not found.
- **`$:` operator prefix semantics:** methods named with a preceding `$:`
  bash-expand that argument first. Plain `:` methods act on the argument
  literally. The full selector matrix is generated (see 3.3).
- **Nested expansion:** the operand of `:-`, `:=`, `:+`, the pattern and the
  replacement parts, and bare `$key` references, may themselves contain
  `${...}` expressions which are expanded recursively.
- **Lazy allocation:** the parser allocates output buffer only when an
  actual expansion or an escape is encountered; plain strings pass through
  unchanged.
- **Backslash escaping** is honored while scanning and when grabbing segments,
  so literal `$`, `{`, `}`, `/` etc. can be produced.

## 3. Core API & Data Structures

### 3.1. `MulleBashStringExpansion.h`

Version macros and query functions. All symbols below are copied verbatim.

```c
#define MULLE_BASH_STRING_EXPANSION_VERSION  ((0UL << 20) | (0 << 8) | 7)

static inline unsigned int   MulleBashStringExpansionG_get_version_major( void)
```

```c
static inline unsigned int   MulleBashStringExpansion_get_version_minor( void)
```

```c
static inline unsigned int   MulleBashStringExpansion_get_version_patch( void)
```

```c
MULLE_BASH_STRING_EXPANSION_GLOBAL
uint32_t   MulleBashStringExpansion_get_version( void);
```

- **Purpose:** report the library version. The packed value is
  `(major << 20) | (minor << 8) | patch`. The static inline accessors decode
  `major`/`minor`/`patch`; `MulleBashStringExpansion_get_version()` returns the
  packed `uint32_t` value at runtime.
- **Note:** the source spells the major accessor
  `MulleBashStringExpansionG_get_version_major` (with an embedded capital `G`).
- This header imports `import.h` and the export header, and conditionally
  imports the (now optional) version-check header.

### 3.2. `NSString+MulleBashStringExpansion.h`

Category on `NSString`. The three entry points into the expansion engine.

```c
@interface NSString ( MulleBashStringExpansion)

// this does @"...${<expr>}...${<expr>}..."
- (NSString *) mulleBashExpandWithDataSource:(id) info;

// this does just @"${<expr>}""
- (NSString *) mulleBashExpandExpressionWithDataSource:(id) info;

// this does only @"<expr>" without the ${}, though ${} will be used for
// subexpression... hmmm
//
// It actually uses -mulleBashExpandExpressionWithDataSource: with a
// wrapped self string.
- (NSString *) mulleExpandExpressionWithDataSource:(id) info;

@end
```

- `mulleBashExpandWithDataSource:` — **whole template** entry point. Processes
  a string that may contain arbitrary text plus zero or more `${expr}` and bare
  `$keypath` expressions. Returns a new `NSString` with all references
  substituted.
- `mulleBashExpandExpressionWithDataSource:` — expects a **single** expression
  of the form `${...}`. Used by the recursive expansion of inner expressions.
- `mulleExpandExpressionWithDataSource:` — expects the **bare** expression
  (no `${...}`), wraps it in `${`/`}`, then delegates to
  `mulleBashExpandExpressionWithDataSource:`. This is what makes `[s $:expr]`
  work.

### 3.3. `S.h` — the `S` class

A class designed for MulleScion. Its methods provide selectors for both plain
string operations and for bash expansion (prefix `$:` means "expand this
argument first").

```c
@interface S : NSObject

// for mulleScion, S will die when locals and dataSource as it will actually
// be in locals
@property( retain) NSMutableDictionary   *locals;
@property( retain) id                    dataSource;

+ (instancetype) objectWithDataSource:(id) dataSource;

+ (instancetype) objectWithMulleScionLocalVariables:(NSMutableDictionary *) locals
                                         dataSource:(id) dataSource;
```

- **Properties:** `locals` (`NSMutableDictionary`, retained) and `dataSource`
  (`id`, retained). Lookup precedence is `locals`, then `dataSource`.
- **Factory methods:** create an instance via `[self object]` + property
  setters. Use `objectWithDataSource:` for the data source only, or
  `objectWithMulleScionLocalVariables:` when a locals dictionary is also
  wanted. There is no `-init`/`-alloc` API in the public header.

#### Plain `:` (literal) methods

```c
// this returns string unaltered
- (id) :(NSString *) string;
```

```c
// this provides [S:"foobar":"o*"], will return { 1, 2 }
- (NSRange) :(NSString *) string
            :(NSString *) pattern;
```

```c
// this provides [S:"foobar":"o*":x], will return "fxbar"
- (id) :(NSString *) string
       :(NSString *) pattern
       :(NSString *) replacement;
```

These delegate to the Foundation `NSString` pattern operations
(`mulleRangeOfPattern:`, `mulleStringByReplacingPattern:`) without any
expansion. `:` with a single argument is the identity function.

#### Mixed and `$:` (bash-expand) variants

`$:` prefixed arguments are first expanded with
`mulleExpandExpressionWithDataSource:self`; `:` arguments are taken literally.

```c
- (id) $:(NSString *) expression;
```

```c
- (NSRange) $:(NSString *) string
             :(NSString *) pattern;

- (NSRange)  :(NSString *) string
            $:(NSString *) pattern;

- (NSRange) $:(NSString *) string
            $:(NSString *) pattern;
```

```c
- (id)  :(NSString *) string
        :(NSString *) pattern
       $:(NSString *) replacement;

- (id)  :(NSString *) string
       $:(NSString *) pattern
        :(NSString *) replacement;

- (id)  :(NSString *) string
       $:(NSString *) pattern
       $:(NSString *) replacement;

- (id) $:(NSString *) string
        :(NSString *) pattern
        :(NSString *) replacement;

- (id) $:(NSString *) string
        :(NSString *) pattern
       $:(NSString *) replacement;

- (id) $:(NSString *) string
       $:(NSString *) pattern
        :(NSString *) replacement;

// same as [S:[S $:string]:[S $:pattern]:[S $:replacement]]
- (id) $:(NSString *) string
       $:(NSString *) pattern
       $:(NSString *) replacement;
```

- **Semantics of each variant:**
  - `[s :s]` returns `s` unaltered.
  - `[s :s :p]` returns `[s mulleRangeOfPattern:p]` (an `NSRange`).
  - `[s :s :p :r]` returns `[s mulleStringByReplacingPattern:p withString:r]`.
  - Each `$:` argument is bash-expanded first via `mulleExpandExpressionWithDataSource:`.
- `NSRange` results are the ranges of the (first) pattern match; the reader
  uses `mulle_printf` to inspect them in the tests.

### 3.4. `generic/MulleObjCDeps+MulleBashStringExpansion.h`

```c
@interface MulleObjCDeps( MulleBashStringExpansion)

+ (struct _mulle_objc_dependency *) dependencies;

@end
```

- **Purpose:** a required public interface used by the mulle-objc runtime to
  declare this library's load dependencies inside a `MulleObjcLoader` class.
  Only compiled when `__MULLE_OBJC__` is defined. Consumers normally do not
  call this directly.

### 3.5. Supported Expansion Syntax

Operators inside `${...}` (parameter/key, then operator, then operand):

| Expression            | Meaning
|-----------------------|-----------------------
| `${parameter}`        | Value of `parameter` (keypath)
| `${parameter:-expr}`  | `expr` if `parameter` is empty, else value
| `${parameter:=key}`   | Value of key-path `key` if `parameter` is empty
| `${parameter:+expr}`  | `expr` if `parameter` is not empty, else `""`
| `${#parameter}` and `${|parameter}` | Length of value (as number); `|` is an alias to avoid MulleScion comment `#`
| `${parameter:offset}` | Substring from `offset`
| `${parameter:offset:length}` | Substring of `length` at `offset`
| `${parameter#pattern}`   | Remove **shortest** matching prefix
| `${parameter##pattern}`  | Remove **longest** matching prefix
| `${parameter%pattern}`   | Remove **shortest** matching suffix
| `${parameter%%pattern}`  | Remove **longest** matching suffix
| `${parameter/pattern/word}`    | Replace **first** match
| `${parameter//pattern/word}`   | Replace **all** matches
| `${parameter/#pattern/word}`   | Replace anchored at prefix
| `${parameter/%pattern/word}`   | Replace anchored at suffix
| `${parameter^pattern}`   | Uppercase first character matching `pattern`
| `${parameter^^pattern}`  | Uppercase all characters matching `pattern`
| `${parameter,pattern}`   | Lowercase first character matching `pattern`
| `${parameter,,pattern}`  | Lowercase all characters matching `pattern`

Semantics of the pattern matching in the implementation:

- **Prefix/suffix removal** (`#`/`##`/`%`/`%%`) uses
  `[string mulleRangeOfPattern:pattern options:options]` with options
  `NSAnchoredSearch | MulleObjCWildcards`, plus `MulleObjCWildcardsShortestPath`
  for the single-`#`/`%` forms and `NSBackwardsSearch` for suffixes.
- **Replacement** (`/`, `//`) uses the wildcard/regex-capturing
  `mulleStringByReplacingPattern:pattern withString:word options:MulleObjCWildcards`;
  `/#` adds `NSAnchoredSearch`, `/%` adds `NSBackwardsSearch`, and `//` loops
  manually over all matches.
- **Case operations** (`^`, `^^`, `,`, `,,`) compile the pattern as a UTF-32
  regex applied to single characters.
- **Nested sub-expressions:** the operand of `:-`, `:=`, `:+`, the pattern of
  `#`/`%`/`/`, and the replacement `word` are all themselves run through
  `mulleBashExpandWithDataSource:` (e.g. `${foo:-${bar}}` works).
- **Bare references** in a template: `mulleBashExpandWithDataSource:` also
  expands `$keypath` (no braces) inside a string, not only `${...}`.
- Backslash escapes are honored while scanning and segment-grabbing.

## 4. Performance Characteristics

- **Single pass:** `mulleBashExpandWithDataSource:` scans the input once with a
  `MulleStringEnumerator`, O(n) in the template length.
- **Lazy allocation:** no intermediate buffer is allocated unless a `$`, `{`,
  `}`, `\` or escape is present; unexpanded input is returned as-is (O(1)).
- **Expansion cost:** each `${...}` triggers a keypath lookup
  `[info valueForKeyPath:key]` (dictionary lookup, roughly O(1) amortized) and
  a `description` conversion of the found value.
- **Pattern operations** delegate to Foundation's `mulleRangeOfPattern` /
  `mulleStringByReplacingPattern` (wildcard/regex engine); the `//` replace-all
  loops iteratively over each match.
- **Case conversion** compiles the pattern once per expression as a UTF-32
  regex and processes characters character-by-character.
- **Nested expansion** recurses; depth is bounded by template nesting and the
  stack. Very deeply nested expressions can exhaust the stack.
- **Thread safety:** this is a mulle-objc library using the default allocator;
  it is not thread-safe and must be externally serialized if shared.
- Memory use is O(output length) plus the enumerator/parser overhead.

## 5. AI Usage Recommendations & Patterns

### Best Practices

- **Use the `S` class when expanding many strings against the same data
  source:** create it once with
  `[S objectWithMulleScionLocalVariables:locals dataSource:info]` (or
  `objectWithDataSource:info`) and reuse it; the instance remembers
  `locals`/`dataSource`.
- **Pick the right entry point:**
  - Whole template with mixed text → `[template mulleBashExpandWithDataSource:info]`.
  - Single `${expr}` → `mulleBashExpandExpressionWithDataSource:`.
  - Bare `expr` (no braces) → `mulleExpandExpressionWithDataSource:` or
    `[s $:expr]` on an `S` instance.
  - Plain strings / no expansion → `[s :string ...]`.
- **Use `$:` prefixes deliberately:** `[s $:s :p :r]` expands only `s`;
  `[s :s :p $:r]` expands only `r`; `[s $:s $:p $:r]` expands all three.
- **Keypaths:** values are resolved with keypath semantics (`"foo.bar"`), so a
  nested dictionary `@{ "foo": @{ "bar": @"foobar" }}` resolves `foo.bar`.
- **Fall back to the GNU Bash manual** for the meaning of operators; the
  library implements the listed subset faithfully.

### Common Pitfalls

- **`#` vs comment tokens:** `${#parameter}` is easily misread as a comment by
  MulleScion script tooling. Use the pipe-alias `${|parameter}` instead.
- **`:=` is a *key*, not a literal default:** `${parameter:=other}` re-reads
  `other` from the data source; use `:-` for a literal default.
- **Values are `description`-converted:** numbers etc. are stringified; a
  missing key yields the empty string, not nil.
- **`${...}` operands may re-expand:** a `:` default or a pattern containing
  another `${...}` will be expanded recursively — escape `$` with `\` if a
  literal `$` is intended.
- **Not all operators share one pattern dialect:** the `#/%` removal operators
  and `//` replacement pass the `MulleObjCWildcards` option to the Foundation
  matcher, while the `^`/`,` case operators compile the pattern as a UTF-32
  regex. Don't assume a POSIX regex works identically everywhere.
- **Not thread-safe** without external synchronization.

### Idiomatic Usage

```objc
sInstance = [S objectWithMulleScionLocalVariables:nil
                                       dataSource:info];
value = [sInstance $:@"foo:-baz"];
```

MulleScion templates call selectors directly, e.g.
`{{ [S :filename :".exe" :".bat"] }}`.

## 6. Integration Examples

### Example 1: Expanding a Template Against a Dictionary

```objc
#import <MulleBashStringExpansion/MulleBashStringExpansion.h>

int   main( void)
{
   NSDictionary   *info;
   NSString       *value;

   info  = @{ @"a": @"vfL",
              @"b": @"BOCHUM",
              @"c": @(1949) };

   value = [@"${a^} ${b,,[C-Z]} ${c//9/8}" mulleBashExpandWithDataSource:info];
   // value is "VfL Bochum 1848"

   return( 0);
}
```

### Example 2: Using the `S` Class with Keypaths

```objc
#import <MulleBashStringExpansion/MulleBashStringExpansion.h>

int   main( void)
{
   NSDictionary   *info;
   NSString       *value;
   S              *s;

   info  = @{ @"foo": @{ @"bar": @"foobar" }};
   s     = [S objectWithMulleScionLocalVariables:nil
                                      dataSource:info];

   value = [s $:@"foo.bar"];     // keypath lookup -> "foobar"
   value = [s $:@"foo.bar:3"];   // substring from offset 3 -> "bar"

   return( 0);
}
```

### Example 3: Plain Replacement and Range on `S`

```objc
#import <MulleBashStringExpansion/MulleBashStringExpansion.h>

int   main( void)
{
   id        r;
   NSRange   range;
   S         *s;

   s     = [S objectWithMulleScionLocalVariables:nil
                                      dataSource:nil];
   r     = [s :@"foobar"
             :@"(o+)"
             :@"x\\1x"];        // regex replacement -> "fxooxbar"
   range = [s :@"foobar"
             :@"(o+)"];         // first match range -> { 1, 2 }

   return( 0);
}
```

### Example 4: MulleScion-style Filename Retagging

```objc
#import <MulleBashStringExpansion/MulleBashStringExpansion.h>

int   main( void)
{
   id   dotexe;
   S    *s;

   s      = [S objectWithMulleScionLocalVariables:nil
                                      dataSource:nil];
   dotexe = [s :@"foo.exe"
               :@".exe"
               :@".com"];       // -> "foo.com"

   return( 0);
}
```

## 7. Dependencies

Direct `mulle-sde` dependencies (from `.mulle/etc/sourcetree/config`):

- `MulleFoundation/MulleFoundationBase` — amalgamated Foundation library
  providing `NSString`, `NSDictionary`, `NSMutableDictionary`, `NSRange`,
  `NSNumber`, keypath lookup, pattern matching, reckless allocator, etc.
- `mulle-objc/mulle-objc-list` — mulle-objc runtime dependency list tooling
  (used at build time for dependency declarations, `no-all-load`,
  `no-bequeath`, `no-cmake-inherit`, `no-header`, `no-import`, `no-link`).

## 8. Limitations & Non-Support

The following Bash features are **not** supported:

- Command substitution: `$()` and backticks
- Arithmetic expansion: `$((...))`
- Tilde expansion (`~/path`)
- Globbing / filename expansion
- Recognition of single/double-quoted strings (no quote-driven semantics)
- Word splitting on expansion
- `${parameter:?...}` error-on-unset and `${parameter@operator}` operators are
  not implemented (the internal token table marks them NYI).
- `${parameter/#pat/str}` / `${parameter/%pat/str}` are a special case: the
  source token table comments mark them NYI, but the parser actually handles
  them (token `token_expand_replace_prefix` / `token_expand_replace_suffix`),
  so `/#` (anchored prefix) and `/%` (anchored suffix) replacement works.

## 9. Standards & References

- Operator semantics follow the [GNU Bash Manual - 3.5.3 Shell Parameter
  Expansion](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html).
- Implementation uses Foundation `NSString` keypath lookup
  (`valueForKeyPath:`), pattern matching (`mulleRangeOfPattern:`,
  `mulleStringByReplacingPattern:`), and wildcard/regex options
  (`NSAnchoredSearch`, `NSBackwardsSearch`, `MulleObjCWildcards`,
  `MulleObjCWildcardsShortestPath`).
- Version macros live in `src/MulleBashStringExpansion.h` (see 3.1).