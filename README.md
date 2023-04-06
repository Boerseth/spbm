# Single WebPage Template (SWePT)
I wanted to make my whole blog just one HTML file, so I've created a template that toggles element-visibility and navigates using URL-fragments, and a script to populate it.


## License
GPL v3.0


## Usage
You should probably not use this.


### Basic usage
But if you must, just create markdown-files of new blog entries in the folder `posts`, and generate the page by running the `mayke` script.

**IMPORTANT**: There are some strong assumptions made on the format of the blog-post header:

  - it must be on the first line of the file
  - it must be the highest level heading (single `#`)
  - it must start with a date in the format `YYYY-MM-DD`, separated from the `@` by a single space
  - the rest of the title must not be empty

Besides that, all it takes is to put a file like

```markdown
<!-- posts/blogpost.md -->
# 2023-04-07 This is a blog-post

It has all kinds of text
```

in the location

```
|- templates/
|- media/
'- posts/
    '- blogpost.md
```

and running

```bash
$ ./mayke
```

resulting in

```
|- templates/
|- media/
|- posts/
'- page/
    |- favicon.png
    '- index.html
```

### Adding media
If you need to put images and stuff in your blog, that can be included in markdown with HTML syntax. Media that you want to host alongside the web-page you can place in the `media` folder, organized however you like. These will all be copied over to the new `page` directory:

```
|- templates/
|- posts/
|- media/
|   |- image_1.png
|   |- sub-folder/
|   |   |- one-of-many-images-2.jpg
...
'- page/
    |- favicon.png
    |- index.html
    |- image_1.png
    |- sub-folder/
    |   |- one-of-many-images-2.jpg
    ...
```

## TODO

  - Allow for injecting CSS
  - Clean up script
