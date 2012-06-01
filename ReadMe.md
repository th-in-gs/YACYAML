# YACYAML

© 2012 James Montgomerie  
jamie@montgomerie.net, [http://www.blog.montgomerie.net/](http://www.blog.montgomerie.net/)  
jamie@th.ingsmadeoutofotherthin.gs, [http://th.ingsmadeoutofotherthin.gs/](http://th.ingsmadeoutofotherthin.gs/)  


## What it is

- YACYAML reads and writes YAML, a friendier, more human, replacement for plists or JSON.
- YACYAML also works as a drop-in replacement for NSKeyedArchiver and NSKeyedUnarchiver in most situations, and writes a human-readable, less proprietary format.
- YACYAML is for iOS and Mac OS X.


## What it does

- YACYAML decodes native Cocoa objects from YAML.
- YACYAML encodes native Cocoa objects to YAML.
- You don't need to know what YAML is to use YACYAML.  Knowing what plain text is helps though.


## How to use YACYAML

- Use `YACYAMLKeyedUnarchiver` fo read YAML files, or the `YACYAMLDecodeAll` methods on `NSString` or `NSData` objects holding YAML strings to decode them.
- Call `-YACYAMLEncodedString` (or `-YACYAMLEncodedData`) on Cocoa objects to get a plain-text YAML encoding.  It'll work on all objects you could store in a plist or in JSON, and any others that support `NSCoding`.
- Use `YACYAMLKeyedArchiver` to encode object graphs, as a replacement for `NSKeyedArchiver`.  
- Use `YACYAMLKeyedUnarchiver` to decode object graphs encoded with `YACYAMLKeyedArchiver`.   `YACYAMLKeyedUnarchiver` is to `YACYAMLKeyedArchiver` as `NSKeyedUnarchiver` is to `NSKeyedArchiver`.
- See below for how to compile and link YACYAML into your Mac or iOS project.


## What's YACYAML's rationale?

Read more at [http://www.blog.montgomerie.net/yacyaml](http://www.blog.montgomerie.net/yacyaml)


## What's YAML?

YAML is a human friendly data serialization standard.  YAML is a friendlier superset of JSON.  YAML is easy for humans to read and write.  

In spirit, YAML is to data representation what Markdown is to text markup.



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
        - Science fiction"
        - Carter, John (Fictitious character) -- Fiction
        - Dejah Thoris (Fictitious character) -- Fiction
        - Mars (Planet) -- Fiction
        - Princesses -- Fiction
    rights: http://www.gutenberg.org/license
    title: A Princess of Mars
```

This is a JSON almost-equivalent - I've tried to indent is as readably as I can:

```JSON
{ 
    "62": { 
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
        "language": "en"
        "lcc": "PS",
        "lcsh": [
            "Science fiction",
            "Carter, John (Fictitious character) -- Fiction",
            "Dejah Thoris (Fictitious character) -- Fiction",
            "Mars (Planet) -- Fiction",
            "Princesses -- Fiction"
        ],
        "rights": "http://www.gutenberg.org/license",
        "title": "A Princess of Mars",
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


And, to show that this can indeed archive arbitrary Cocoa objects (that implement `NSCoder`), here's a good old Mac OS NSButton.  You wouldn't, of course, write this by hand, but I think there's value in having it stored in a human-readable format rather than what NSKeyedArchiver emits.

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

YACYAML is designed to be built as an static library and used directly by Xcode, as a subproject to an your project.  (like [this](http://www.blog.montgomerie.net/easy-xcode-static-library-subprojects-and-submodules)).

The short version of how to set up your iOS or Mac project to build and use YACYAML:
- Copy the YACYAML directory into, or (better) clone a YACYAML repository as a Git submodule in, your app project's directory hierarchy somewhere.
- In your app's Xcode project, drag the YACYAML.project into the navigator tree on the left.
- In your app's Xcode target settings, in the _Build Phases_ section:
-- Under _Target Dependencies_, press the '+' button, and add the _YACYAML_ target from the _YACYAML_ project.
-- Under _Link Binary With Libraries_, press the '+' button, and add _libYACYAML.a_ the _YACYAML_ project.
-- Under _Link Binary With Libraries_, press the '+' button, and add _libresolv.dylib_ from your target SDK (libresolv provides Base64 encoding, used by YACYAML when reading and writing NSData objects).
- In your app's target settings, in the _Build Settings_ section:
-- Make sure _All_, not _Basic_ is selected at the top.
-- On the _Header Saearch Paths_ line, add `"$(TARGET_BUILD_DIR)/usr/local/lib/include"` and `"$(OBJROOT)/UninstalledProducts/include"` (make sure to include the quotes!)
-- On the _Other Linker Flags_ line, make sure the flags `-ObjC` and `-all_load` are there (add them if they're not).
- When you want to use YACYAML, just `#import <YACYAML/YACYAML.h>`.


## YACYAML?

YACYAML stood for _Yet Another Cocoa YAML_, but I think it deserves better than that now.


## Thanks to

- _why the lucky stiff_for his _Syck_ YAML parser, and Will Thimbleby for his Cocoa extensions to Syck.  Syck's now sadly rather old and somewhat busted, but it's what originally got me using YAML.
- Kirill Simonov for [libyaml](http://pyyaml.org/wiki/LibYAML), which YACYAML uses to parse and emit raw YAML, and without which I don't think I'd have contemplated this.