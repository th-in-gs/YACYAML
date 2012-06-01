# YACYAML

© 2012 James Montgomerie  
jamie@montgomerie.net, [http://www.blog.montgomerie.net/](http://www.blog.montgomerie.net/)  
jamie@th.ingsmadeoutofotherthin.gs, [http://th.ingsmadeoutofotherthin.gs/](http://th.ingsmadeoutofotherthin.gs/)  


## What it is

- YACYAML reads and writes YAML, a friendier, more human, replacement for plists or JSON.
- YACYAML also works as a drop-in replacement for NSKeyedArchiver and NSKeyedUnarchiver in most situations.
- YACYAML is for iOS and Mac OS X.


## What it does

- YACYAML decodes native Cocoa objects from YAML.
- YACYAML encodes native Cocoa objects to YAML.
- You don't need to know what YAML is to use YACYAML.  Knowing what plain text is helps though.


## How to use YACYAML

Just call `-YACYAMLEncodedString` (or `-YACYAMLEncodedData`) on Cocoa objects to get a plain-text YAML encoding.  It'll work on all objects you could store in a plist or in JSON, and any others that support `NSCoding`.

Use `YACYAMLKeyedArchiver` to encode object graphs, as a replacement for `NSKeyedArchiver`.  

Use `YACYAMLKeyedUnarchiver` to decode object graphs encoded with `YACYAMLKeyedArchiver`.   `YACYAMLKeyedUnarchiver` is to `YACYAMLKeyedArchiver` as `NSKeyedUnarchiver` is to `NSKeyedArchiver`.


## What's YACYAML's rationale?

Read more at [http://www.blog.montgomerie.net/yacyaml](http://www.blog.montgomerie.net/yacyaml)


## What's YAML?

YAML is a human friendly data serialization standard.  YAML is a friendlier superset of JSON.  YAML is easy for humans to read and write.  

In spirit, YAML is to data representation what Markdown is to text markup.



## Example hand-written YAML

This is a simple dctionary, represented in YAML.  It would decode as an NSDictionary.  But you can probably guess that, because YAML is designed to be easy for humans to read.  

Just imagine how gigantic this would be as a plist.

```YAML
date: 2012-04-01
etextNumber: 62
title: A Princess of Mars
author: Edgar Rice Burroughs
kind: reader
picker: Joseph
synopsis: >-
    This first book in the Barsoom series follows American John Carter as he
    explores Mars after being transported there by forces unknown. Carter
    battles with gigantic Tharks, explores the red planet and chases after
    Dejah Thoris, Princess of Helium. A influential work of sci-fi that has
    inspired writers & readers for nearly a century.
```


## Example encoded Cocoa objects

An array of strings:

```ObjC
[[NSArray arrayWithObjects:@"one", @"two", @"three", nil] YACYAMLEncodedString];
```

```
- one
- two
- three
```

A dictionary of strings:

```ObjC
[[NSDictionary dictionaryWithObjectsAndKeys:@"one", @"onekey",
                                            @"two", @"twokey",
                                            @"three", @"threekey",
                                            nil] YACYAMLEncodedString];
```

```
onekey: one
twokey: two
threekey: three
```

A whole UIButton:

```ObjC



```

```

```


## YACYAML handles repeated encoding of identical objects, and object graphs, sensibly.

YACYAML uses YAML's 'anchors' to store repeated objects only once, and refer to them later.  By default, repeated strings are stored, for human-readability, but you can change that behaviour id you want smaller, but less human-readable output.  Check out `YACYAMLKeyedArchiver`'s `YACYAMLKeyedArchiverOptionAllowScalarAnchors` option.


## YACYAML?

YACYAML stood for _Yet Another Cocoa YAML_, but I think it deserves better than that now.


## Thanks to

_why the lucky stiff_for his _Syck_ YAML parser, and Will Thimbleby for his Cocoa extensions to Syck.  Syck's now sadly rather old and somewhat busted, but it's what originally got me using YAML.
Kirill Simonov for [libyaml](http://pyyaml.org/wiki/LibYAML), which YACYAML uses to parse and emit raw YAML, and without which I don't think I'd have contemplated this.