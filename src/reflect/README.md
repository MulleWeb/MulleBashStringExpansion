# Header files in `reflect`

## External consumption only

### `MulleBashStringExpansion-export.h`

This file is generated for the Objective-C envelope header (typically
`MulleBashStringExpansion
.h`). It contains the list of Objective-C headers that
are advertised to consumers of this library


### `MulleBashStringExpansion-provide.h`

This file is generated for the Objective-C or C envelope header (typically
`MulleBashStringExpansion
.h`). It contains the list of C headers that will be
advertised to consumers of this library.


### `objc-loader.inc`

This file contains Objective-C dependency information of this library.
It's updated during a build.


## Internal and External consumption


### `MulleBashStringExpansion-import.h`

Objective-C dependency headers that this project uses are imported via
this file. Dependencies are managed with `mulle-sde dependency`
These dependencies are also available to consumers of this library.


### `MulleBashStringExpansion-include.h`

C dependency and library headers that this project uses are imported via
this file. Dependencies are managed with `mulle-sde dependency`.
Libraries with `mulle-sde library`.
These dependencies are also available to consumers of this library.


## Internal consumption only


### `MulleBashStringExpansion-import-private.h`

Objective-C dependency headers that this project uses privately are imported
via this file.


### `MulleBashStringExpansion-include-private.h`

C dependency and library headers that this project uses privately are imported
via this file.
