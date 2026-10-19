# YACYAML

© 2012-2026 James Montgomerie  
jamie@montgomerie.net, [http://www.blog.montgomerie.net/](http://www.blog.montgomerie.net/)  
jamie@th.ingsmadeoutofotherthin.gs, [http://th.ingsmadeoutofotherthin.gs/](http://th.ingsmadeoutofotherthin.gs/)  


## What it is

- YACYAML reads and writes YAML, a friendlier, more human, plain text replacement for plists or JSON.
- YACYAML also works as a drop-in replacement for NSKeyedArchiver and NSKeyedUnarchiver in most situations, and writes a human-readable, less proprietary format.
- YACYAML is for iOS and Mac OS X.


## What it does

- YACYAML decodes native Cocoa objects from YAML.
- YACYAML encodes native Cocoa objects to YAML.
- You don't need to know what YAML is to use YACYAML.  Knowing what plain text is helps though.


## How to use YACYAML

- Use `YACYAMLKeyedUnarchiver` to read YAML, or the `-YACYAMLDecode` methods on `NSString` or `NSData` objects holding YAML strings to decode them.
- Call `-YACYAMLEncodedString` (or `-YACYAMLEncodedData`) on Cocoa objects to get a plain-text YAML encoding.  It'll work on all objects you could store in a plist or in JSON, and any others that support `NSCoding`.
- Use `YACYAMLKeyedArchiver` to encode object graphs, as a replacement for `NSKeyedArchiver`.  
- Use `YACYAMLKeyedUnarchiver` to decode object graphs encoded with `YACYAMLKeyedArchiver`.   `YACYAMLKeyedUnarchiver` is to `YACYAMLKeyedArchiver` as `NSKeyedUnarchiver` is to `NSKeyedArchiver`.
- If you are decoding YAML from a source you don't control, see _Decoding YAML you don't trust_ below.
- See below for how to compile and link YACYAML into your Mac or iOS project.


## Decoding YAML you don't trust

By default, `YACYAMLKeyedUnarchiver` behaves like `NSKeyedUnarchiver`: a tag that names a class (`!SomeClass`) makes it create an object of that class and call `-initWithCoder:` on it.  That is what lets it decode arbitrary Cocoa objects, but it also means that YAML from an untrusted source can make it instantiate any class that your process knows about.

If you're decoding YAML that you don't control, switch on `YACYAMLKeyedUnarchiverOptionDisallowInitWithCoder`:

```ObjC
id decoded = [YACYAMLKeyedUnarchiver unarchiveObjectWithString:yaml
                                                       options:YACYAMLKeyedUnarchiverOptionDisallowInitWithCoder];
```

With the option on, tagged mappings and sequences come back as plain `NSDictionary`s and `NSArray`s, and `-initWithCoder:` is never called.  The YAML types listed below under _How much YAML does this support?_ still decode to their Cocoa equivalents.  (Classes that you've deliberately taught the unarchiver to build, using its `YACYAMLUnarchiving…` protocols, are still created.)

The `-YACYAMLDecode` and `-YACYAMLDecodeBasic` methods on `NSString` and `NSData` already set this option.  `-YACYAMLDecodeAll` doesn't, and decodes the same way as `YACYAMLKeyedUnarchiver` does by default.

If you'd rather not let any local tag (YAML's name for a tag that starts with a single `!`, like `!ClassName`) have an effect, use `YACYAMLKeyedUnarchiverOptionDisallowLocalTags`.  Local tags are then ignored, and what has one is read as if it had none: mappings and sequences become `NSDictionary`s and `NSArray`s, and scalars become strings.  Global tags, like `!!int` (which is `tag:yaml.org,2002:int`), still work.  This is stricter than `DisallowInitWithCoder` for classes that you've registered with a local tag, which it also ignores, but it doesn't stop `-initWithCoder:` being called for a class that you've registered with a global tag.  The two options can be used together.

`YACYAMLKeyedArchiverOptionDisallowLocalTags` is the same idea for writing: archiving an object that would be written with a local tag (any object that is encoded with `-encodeWithCoder:` is, as it's tagged with its class name) raises an exception, before anything is written, so that application objects can't get into the output by accident.

This limits which objects get created.  It isn't a sandbox - it doesn't, for example, limit the size of the input.


## What's YACYAML's rationale?

Read more at [http://www.blog.montgomerie.net/yacyaml](http://www.blog.montgomerie.net/yacyaml)


## What's YAML?

YAML is a human friendly data serialization standard.  YAML is a friendlier superset of JSON.  YAML is easy for humans to read and write.  

In spirit, YAML is sort of to data representation what Markdown is to text markup.



## Example hand-written YAML

This is a simple dictionary represented in YAML.  It would decode as an NSDictionary.  But you can probably guess that, because YAML is designed to be easy for humans to read.  

Just imagine how gigantic this would be as a plist.

```YAML
date: 2012-04-01
etextNumber: 62
title: A Princess of Mars
author: Edgar Rice Burroughs
picker: Joseph
pickerIsReader: y
synopsis: >-
    This first book in the Barsoom series follows American John Carter as he
    explores Mars after being transported there by forces unknown. Carter
    battles with gigantic Tharks, explores the red planet and chases after
    Dejah Thoris, Princess of Helium. A influential work of sci-fi that has
    inspired writers & readers for nearly a century.
```

A more complex example, with nested elements.  This is an excerpt from [Eucalyptus](http://eucalyptusapp.com/)' catalog of books.  I hope you'll agree it's nicer than a plist.  I also think it's nicer than JSON (which, incidentally, couldn't represent this structure fully, because it uses integers - `62` in this excerpt - as dictionary keys):

```YAML
62:
    title: A Princess of Mars
    creator: Burroughs, Edgar Rice, 1875-1950
    description: Barsoom series, volume 1
    file:
        extent: 148804
        format:
            - text/plain; charset="us-ascii"
            - application/zip
    modified: 2012-03-26
    url: http://www.gutenberg.org/dirs/6/62/62.zip
    language: en
    lcc: PS
    lcsh:
        - Science fiction
        - Carter, John (Fictitious character) -- Fiction
        - Dejah Thoris (Fictitious character) -- Fiction
        - Mars (Planet) -- Fiction
        - Princesses -- Fiction
    rights: http://www.gutenberg.org/license
```

This is a JSON almost-equivalent - I've tried to indent is as readably as I can:

```JSON
{ 
    "62": { 
        "title": "A Princess of Mars",
        "creator": "Burroughs, Edgar Rice, 1875-1950",
        "description": "Barsoom series, volume 1",
        "file": { 
            "modified": "2012-03-26",
            "url": "http://www.gutenberg.org/dirs/6/62/62.zip",
            "format": [
                "text/plain; charset=\"us-ascii\"",
                "application/zip"
            ],
          "extent": 148804
        },
        "language": "en",
        "lcc": "PS",
        "lcsh": [
            "Science fiction",
            "Carter, John (Fictitious character) -- Fiction",
            "Dejah Thoris (Fictitious character) -- Fiction",
            "Mars (Planet) -- Fiction",
            "Princesses -- Fiction"
        ],
        "rights": "http://www.gutenberg.org/license"
    }
}
```



## Example encoded objects

An array of strings:

```ObjC
[[NSArray arrayWithObjects:@"one", @"two", @"three", nil] YACYAMLEncodedString];
```

```YAML
- one
- two
- three
```

Also valid is, for example, `[one, two, three]`

A dictionary of strings:

```ObjC
[[NSDictionary dictionaryWithObjectsAndKeys:@"one", @"onekey",
                                            @"two", @"twokey",
                                            @"three", @"threekey",
                                            nil] YACYAMLEncodedString];
```

```YAML
onekey: one
twokey: two
threekey: three
```

You could also write, for example, `{ onekey: one, twoKey: two, threeKey: three }`


And, to show that this can indeed archive arbitrary Cocoa objects (that implement NSCoder), here's a good old Mac OS NSButton.  You wouldn't, of course, write this by hand, but I think there's value in having it stored in a human-readable format rather than what NSKeyedArchiver emits.

```ObjC
NSButton *button = [[NSButton alloc] initWithFrame:NSMakeRect(20, 20, 400, 50)];
button.buttonType = NSPushOnPushOffButton;
button.bezelStyle = NSBezelBorder;
button.title = @"If you wanna come to my house, then click me with your mouse.";

NSString *yaml = [YACYAMLKeyedArchiver archivedStringWithRootObject:button];
```

```YAML
&a !NSButton
NSNextResponder: 
NSvFlags: 256
NSFrame: '{{20, 20}, {400, 50}}'
NSTag: -1
NSEnabled: y
NSCell: !NSButtonCell
  NSCellFlags: 67239424
  NSCellFlags2: 134217728
  NSContents: If you wanna come to my house, then click me with your mouse.
  NSSupport: &b !NSFont
    NSName: LucidaGrande
    NSSize: 12
    NSfFlags: 4880
  NSControlView: *a
  NSButtonFlags: -1232977665
  NSButtonFlags2: 2
  NSAlternateImage: *b
  NSKeyEquivalent: ''
  NSPeriodicDelay: 400
  NSPeriodicInterval: 75
```

If you want to know more, Wikipedia has a lot of good YAML examples and explanations on its [page on YAML](http://en.wikipedia.org/wiki/YAML), or you could read up on the esoteric details at the [home of the YAML spec](http://www.yaml.org/) (you really don't need to just to use it though).


## YACYAML handles repeated encoding of identical objects, and object graphs, sensibly.

YACYAML uses YAML's 'anchors' to store repeated objects only once, and refer to them later.  You can see an example of this in the encoded NSButton, above - it uses an anchor named 'a', and one named 'b'.  By default, repeated strings _are_ stored repeatedly, for human-readability, but you can change that behaviour if you want smaller, but less human-readable output.  Check out `YACYAMLKeyedArchiver`'s `YACYAMLKeyedArchiverOptionAllowScalarAnchors` option.  


## How to use YACYAML in your iOS or Mac project

YACYAML is designed to be built as an static library and used directly by Xcode, as a subproject to your project.  (like [this](http://www.blog.montgomerie.net/easy-xcode-static-library-subprojects-and-submodules)).  It should work correctly on any OS that supports Automatic Reference Counting (your project doesn't need to use ARC itself though - non-ARC code interoperates perfectly well with libraries that use it).

How to set up your iOS or Mac project to build and use YACYAML:
- Copy the YACYAML directory into, or (better) clone a YACYAML repository as a Git submodule in, your app project's directory hierarchy somewhere.
- In your app's Xcode project, drag the YACYAML.project into the navigator tree on the left.
- In your app's Xcode target settings, in the _Build Phases_ section:
    - Under _Target Dependencies_, press the '+' button, and add the _YACYAML_ target from the _YACYAML_ project.
    - Under _Link Binary With Libraries_, press the '+' button, and add _libYACYAML.a_ the _YACYAML_ project.
    - Under _Link Binary With Libraries_, press the '+' button, and add _libresolv.dylib_ from your target SDK (libresolv provides Base64 encoding, used by YACYAML when reading and writing NSData objects).
- In your app's target settings, in the _Build Settings_ section:
    - Make sure _All_, not _Basic_ is selected at the top.
    - On the _Header Search Paths_ line, add `"$(TARGET_BUILD_DIR)/usr/local/lib/include"` and `"$(OBJROOT)/UninstalledProducts/include"` (make sure to include the quotes!)
    - On the _Other Linker Flags_ line, make sure the flags `-ObjC` and `-all_load` are there (add them if they're not).
    - If your project's not already using ARC, you'll also need to add `-fobjc-arc` to the _Other Linker Flags_ (don't worry, that won't make Xcode think your project is using ARC too, it just links in the required support libraries for it so that YACYAML can use it).
- When you want to use YACYAML, just `#import <YACYAML/YACYAML.h>`.


## How much YAML does this support?

It should hopefully parse everything 'sensibly', but specific mappings from/to Cocoa objects (and C basic types, when using the appropriate NSCoder methods) to/from [YAML language-independent types](http://yaml.org/type/) exist for:

### Collections
- Sequences ([`!!seq`](http://yaml.org/type/seq.html)) to/from `NSArray`s
- Mappings ([`!!map`](http://yaml.org/type/map.html)) to/from `NSDictionary`s
- Sets ([`!!set`](http://yaml.org/type/set.html)) to/from `NSSet`s

### Scalars
- Strings ([`!!str`](http://yaml.org/type/str.html)) to/from `NSString`s
- Numbers and booleans ([`!!int`](http://yaml.org/type/int.html), [`!!float`](http://yaml.org/type/float.html), [`!!bool`](http://yaml.org/type/bool.html)) to/from `NSNumbers`s (and equivalent basic types).
- Timestamps ([`!!timestamp`](http://yaml.org/type/timestamp.html)) to/from `NSDate`s
- Binary data ([`!!binary`](http://yaml.org/type/binary.html)) to/from `NSData`s
- Null ([`!!null`](http://yaml.org/type/null.html)) to/from `NSNull`
- Merging of mappings ([`!!merge`](http://yaml.org/type/merge.html))

### Unsupported
- Pairs ([`!!pairs`](http://yaml.org/type/pairs.html))
    - You'll get an array of dictionaries containing one key and value each (this is actually compliant with the spec, given that Cocoa has no pair class).
- Ordered mappings ([`!!omap`](http://yaml.org/type/omap.html))
    - You'll get an ordered array of dictionaries containing one key and value each (this is, again, compliant with the spec given that Cocoa has no ordered mapping class).
- Default values for mappings ([`!!value`](http://yaml.org/type/value.html))
    - You'll get mappings with '=' key representing the default value. This may be spec-compliant, depending on how you think about default values.
- YAML in YAML ([`!!yaml`](http://yaml.org/type/yaml.html))


## YACYAML?

YACYAML stood for _Yet Another Cocoa YAML_, but I think it deserves better than that now.


## Thanks to

- _why the lucky stiff_ for his _Syck_ YAML parser, and Will Thimbleby for his Cocoa extensions to Syck.  Syck's now sadly rather old and somewhat busted, but it's what originally got me using YAML.
- Kirill Simonov for [libyaml](http://pyyaml.org/wiki/LibYAML), which YACYAML uses to parse and emit raw YAML, and without which I don't think I'd have contemplated this.
- [Mike Ash](http://mikeash.com/) for his old MAKeyedArchiver, which illuminated some things, and made me feel not so bad about how this decodes object cycles.
- Everyone who has contributed to YACYAML: see [AUTHORS.md](AUTHORS.md).
