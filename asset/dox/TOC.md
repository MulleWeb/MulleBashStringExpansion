# MulleBashStringExpansion Library Documentation for AI

## 1. Introduction & Purpose

**MulleBashStringExpansion** provides Bash-style string parameter expansion for Objective-C NSString, enabling powerful template substitution and string transformation directly in Objective-C code. This library implements a subset of the Bash shell's parameter expansion syntax, making it ideal for template engines, configuration systems, and dynamic string generation.

This library is particularly useful for:
- Template rendering with variable substitution
- Configuration file processing with dynamic values
- Building strings with conditional defaults
- String transformations (uppercase, lowercase, substring, replace)
- DSL and scripting language implementation
- Generating SQL/HTML/code with safe variable insertion

## 2. Key Concepts & Design Philosophy

- **Bash Compatibility**: Implements common Bash parameter expansions from the GNU Bash manual
- **Nested Expressions**: Supports nested `${...}` expressions for complex substitution
- **Data Source Pattern**: Flexible info object provides variable values via Objective-C key paths
- **Pattern Matching**: Uses regex patterns for prefix/suffix removal and replacement
- **Case Transformation**: Built-in uppercase/lowercase with optional pattern matching
- **Default Values**: Conditional expressions for null/empty handling
- **No External Execution**: Pure Objective-C; no subprocess or shell invocation

## 3. Core API & Data Structures

### NSString Category: `NSString (MulleBashStringExpansion)`

#### Main Expansion Methods

- `- (NSString *) mulleBashExpandWithDataSource:(id)info` → `NSString *`
  - Expand all `${...}` expressions in the receiver string
  - **info**: Data source object (dictionary or custom object with key-value access)
  - Returns expanded string with all variables substituted
  - Supports nested expressions: `${outer_${inner}}`
  - **Use case**: Template expansion with multiple variables

- `- (NSString *) mulleBashExpandExpressionWithDataSource:(id)info` → `NSString *`
  - Expand a single Bash expression (must be in `${...}` form)
  - Input like `${parameter:-default}`
  - Returns result of the expansion
  - **Use case**: Processing individual expressions

- `- (NSString *) mulleExpandExpressionWithDataSource:(id)info` → `NSString *`
  - Expand expression without outer `${...}` wrapper
  - Input like `parameter:-default` (the `${}` added automatically)
  - Internally uses `mulleBashExpandExpressionWithDataSource:`
  - **Use case**: Simpler API when `${}` not needed

### 3.2 Supported Expansion Syntax

#### Variable Substitution

- `${parameter}` → Expand to value of parameter
- `${parameter:-default}` → Use parameter, or default if empty
- `${parameter:=alternate}` → Use alternate instead of parameter if empty
- `${parameter:+value}` → Use value if parameter is not empty, otherwise empty

#### String Length

- `${#parameter}` → Return length of parameter as number

#### Substring Operations

- `${parameter:offset}` → Substring starting at offset
- `${parameter:offset:length}` → Substring starting at offset with maximum length

#### Pattern Removal

- `${parameter#pattern}` → Remove shortest prefix matching regex pattern
- `${parameter##pattern}` → Remove longest prefix matching regex pattern
- `${parameter%pattern}` → Remove shortest suffix matching regex pattern
- `${parameter%%pattern}` → Remove longest suffix matching regex pattern

#### Pattern Replacement

- `${parameter/pattern/replacement}` → Replace first occurrence of regex with replacement
- `${parameter//pattern/replacement}` → Replace all occurrences

#### Case Transformation

- `${parameter^pattern}` → Uppercase first character matching pattern
- `${parameter^^pattern}` → Uppercase all characters matching pattern
- `${parameter,pattern}` → Lowercase first character matching pattern
- `${parameter,,pattern}` → Lowercase all characters matching pattern

#### Nested Expressions

- `${outer${inner}}` → Inner expression evaluated first, then outer
- `${param:-${fallback}}` → Conditional nesting

### 3.3 Data Source Requirements

The info object can be:
- **NSDictionary**: Keys are parameter names, values are NSString or NSNumber
- **Custom Object**: Supports key-value access via KVC (Key-Value Coding)
- **nil**: All expansions resolve to empty string

**Example**:
```objc
NSDictionary *vars = @{
    @"name": @"Alice",
    @"greeting": @"Hello",
    @"count": @42
};

NSString *template = @"${greeting}, ${name}! Items: ${count}";
NSString *result = [template mulleBashExpandWithDataSource:vars];
// Result: "Hello, Alice! Items: 42"
```

### 3.4 Pattern Types

Patterns support:
- **Literal strings**: Match exact text
- **Regex patterns**: Full regex syntax including character classes, quantifiers, etc.
- **Escaped characters**: Backslash escapes honored (e.g., `\.` for literal dot)

## 4. Performance Characteristics

- **Parsing**: O(n) single pass through input string
- **Expansion**: O(n + m) where n = input, m = number of variable lookups
- **Memory**: O(p) where p = output length; allocates result string only once
- **Pattern Matching**: O(m) per pattern match using standard regex engine
- **Nesting**: Recursive, depth limited by system stack
- **Typical**: < 1ms for templates with 10-20 variables

## 5. AI Usage Recommendations & Patterns

### Pattern 1: Simple Variable Substitution
Replace placeholders with values:

```objc
NSDictionary *data = @{
    @"name": @"World",
    @"version": @"1.0"
};

NSString *template = @"Hello ${name}! Version: ${version}";
NSString *result = [template mulleBashExpandWithDataSource:data];
// Result: "Hello World! Version: 1.0"
```

### Pattern 2: Conditional Defaults
Use default values when variables are empty:

```objc
NSDictionary *config = @{
    @"port": @"",  // Empty
    @"host": @"localhost"
};

NSString *connStr = @"${host}:${port:-8080}";
NSString *result = [connStr mulleBashExpandWithDataSource:config];
// Result: "localhost:8080" (port defaults to 8080)
```

### Pattern 3: Substring Extraction
Extract parts of strings:

```objc
NSDictionary *data = @{@"filename": @"document.pdf"};

NSString *template = @"${filename:0:8}";  // First 8 chars
NSString *result = [template mulleBashExpandWithDataSource:data];
// Result: "document"
```

### Pattern 4: String Replacement
Find and replace patterns:

```objc
NSDictionary *data = @{
    @"url": @"http://example.com/api/v1/data"
};

NSString *template = @"${url//api/service}";
NSString *result = [template mulleBashExpandWithDataSource:data];
// Result: "http://example.com/service/v1/data"
```

### Pattern 5: Case Transformation
Convert case of substrings:

```objc
NSDictionary *data = @{@"name": @"john doe"};

NSString *upper = @"${name^^}";  // Uppercase all
NSString *title = @"${name^}";   // Uppercase first

NSString *resultUpper = [upper mulleBashExpandWithDataSource:data];
NSString *resultTitle = [title mulleBashExpandWithDataSource:data];
// resultUpper: "JOHN DOE"
// resultTitle: "John doe"
```

### Pattern 6: Prefix/Suffix Removal
Strip patterns from strings:

```objc
NSDictionary *data = @{@"path": @"/usr/local/bin/program"};

NSString *basename = @"${path##.*/}";  // Remove all up to last /
NSString *result = [basename mulleBashExpandWithDataSource:data];
// Result: "program"
```

### Pattern 7: Nested Expressions
Complex substitution scenarios:

```objc
NSDictionary *data = @{
    @"primary": @"",
    @"secondary": @"fallback_value",
    @"tertiary": @"default"
};

NSString *template = @"${primary:-${secondary:-${tertiary}}}";
NSString *result = [template mulleBashExpandWithDataSource:data];
// Result: "fallback_value" (primary empty, secondary has value)
```

### Pattern 8: Template for SQL/Code Generation
Safely generate SQL with variable substitution:

```objc
NSDictionary *params = @{
    @"table": @"users",
    @"column": @"email",
    @"value": @"john@example.com"
};

NSString *query = @"SELECT * FROM ${table} WHERE ${column} = '${value}'";
NSString *result = [query mulleBashExpandWithDataSource:params];
// Result: "SELECT * FROM users WHERE email = 'john@example.com'"
```

### Common Pitfalls
- **Empty vs nil**: `${var:-default}` triggers on empty string AND nil
- **Regex escaping**: Patterns are regex; use `\.` for literal dot, not just `.`
- **Pattern quantifiers**: `*` is greedy; use non-greedy patterns if needed
- **Nested depth**: Very deep nesting can hit stack limits
- **No command substitution**: `$()` and backticks are NOT supported
- **Case sensitivity**: Parameters are case-sensitive

## 6. Integration Examples

### Example 1: Configuration System
```objc
@interface ConfigExpander : NSObject
- (NSString *) expandConfigValue:(NSString *)template;
@end

@implementation ConfigExpander {
    NSMutableDictionary *_env;
}

- (id)init {
    self = [super init];
    if (self) {
        _env = [[NSMutableDictionary alloc] init];
        // Load from system environment or config file
        [_env setObject:@"/var/app" forKey:@"APP_ROOT"];
        [_env setObject:@"production" forKey:@"ENV"];
    }
    return self;
}

- (NSString *) expandConfigValue:(NSString *)template {
    return [template mulleBashExpandWithDataSource:_env];
}

- (void)dealloc {
    [_env release];
    [super dealloc];
}
@end

// Usage:
ConfigExpander *expander = [[ConfigExpander new] autorelease];
NSString *logPath = [expander expandConfigValue:@"${APP_ROOT}/logs/${ENV}.log"];
// Result: "/var/app/logs/production.log"
```

### Example 2: Email Template Engine
```objc
NSString *emailTemplate = @"Subject: Welcome ${name}!\n\n"
    @"Dear ${name},\n\n"
    @"Welcome to our service. Your account:\n"
    @"Username: ${username}\n"
    @"Email: ${email}\n"
    @"Status: ${status:-pending}\n\n"
    @"Best regards,\nThe Team";

NSDictionary *user = @{
    @"name": @"Alice Johnson",
    @"username": @"alice_j",
    @"email": @"alice@example.com"
};

NSString *emailBody = [emailTemplate mulleBashExpandWithDataSource:user];
```

### Example 3: Path Construction with Defaults
```objc
@interface PathBuilder : NSObject
- (NSString *) buildPath:(NSString *)template;
@end

@implementation PathBuilder {
    NSMutableDictionary *_defaults;
}

- (id)init {
    self = [super init];
    if (self) {
        _defaults = [[NSMutableDictionary alloc] init];
        [_defaults setObject:NSHomeDirectory() forKey:@"HOME"];
        [_defaults setObject:@"/tmp" forKey:@"TMPDIR"];
        [_defaults setObject:@"app" forKey:@"APPNAME"];
    }
    return self;
}

- (NSString *) buildPath:(NSString *)template {
    return [template mulleBashExpandWithDataSource:_defaults];
}

- (void)dealloc {
    [_defaults release];
    [super dealloc];
}
@end

// Usage:
PathBuilder *pb = [[PathBuilder new] autorelease];
NSString *configPath = [pb buildPath:@"${HOME}/.${APPNAME}/config.plist"];
```

### Example 4: String Transformation Pipeline
```objc
- (NSString *) processFilename:(NSString *)original {
    NSDictionary *data = @{@"original": original};
    
    // Remove extension
    NSString *noExt = [original mulleBashExpandWithDataSource:data];
    // If pattern removes .* at end
    data = @{@"name": [noExt substringToIndex:[noExt length] - 4]};
    
    // Make uppercase and add timestamp
    NSString *final = [@"${name^^}_${timestamp}" mulleBashExpandWithDataSource:data];
    return final;
}
```

### Example 5: CLI Argument Template
```objc
- (NSArray *) buildCommandLine:(NSString *)template withArguments:(NSDictionary *)args {
    NSString *expanded = [template mulleBashExpandWithDataSource:args];
    return [expanded componentsSeparatedByString:@" "];
}

// Usage:
NSDictionary *args = @{
    @"compiler": @"clang",
    @"flags": @"-O2 -Wall",
    @"input": @"source.c",
    @"output": @"program"
};

NSString *cmdTemplate = @"${compiler} ${flags:-} -o ${output} ${input}";
NSArray *cmd = [self buildCommandLine:cmdTemplate withArguments:args];
// Result: @[@"clang", @"-O2", @"-Wall", @"-o", @"program", @"source.c"]
```

### Example 6: Conditional Content Rendering
```objc
NSString *template = @""
    @"${env:+Production}${env:-Development} "
    @"${debug:+[DEBUG]: }${appname} ${version}";

NSDictionary *debug = @{
    @"env": @"prod",
    @"debug": @"1",
    @"appname": @"MyApp",
    @"version": @"2.1"
};

NSString *result = [template mulleBashExpandWithDataSource:debug];
// Result: "Production [DEBUG]: MyApp 2.1"
```

### Example 7: Complex String Processing
```objc
- (NSString *) normalizeURLPath:(NSString *)path {
    NSDictionary *data = @{@"path": path};
    
    // Remove trailing slashes, convert to lowercase
    NSString *result = [@"${path%%/*}/${path##.*\/}" mulleBashExpandWithDataSource:data];
    return [[result lowercaseString] stringByTrimmingCharactersInSet:
        [NSCharacterSet characterSetWithCharactersInString:@"/"]];
}
```

## 7. Dependencies

- **MulleFoundation** - NSString base class, KVC support
- **mulle-objc** (runtime) - Objective-C runtime support
- **Regex Engine**: Standard mulle-objc or Foundation regex support
- Standard C library

## 8. Limitations & Non-Support

The following Bash features are **NOT** supported:
- Command substitution: `$()` and backticks
- Arithmetic expansion: `$((...))` 
- Process substitution: `<(...)` and `>(...)` 
- Tilde expansion: `~/path`
- Glob patterns: `*`, `?`, `[...]`
- Quoted strings: No special handling for single or double quotes
- Word splitting: No automatic field splitting

## 9. Standards & References

- Based on: [GNU Bash Manual - 3.5.3 Shell Parameter Expansion](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html)
- Regex Engine: Standard Objective-C NSRegularExpression or similar
- String Processing: NSString/NSMutableString from MulleFoundation

## 10. Version Information

MulleBashStringExpansion version macro: `MULLE_BASH_STRING_EXPANSION_VERSION`
- Format: `(major << 20) | (minor << 8) | patch`
- Tracks both wrapper and core expansion engine versions
