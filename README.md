# Single Page web-LOg SHell-script (splo.sh)

I wanted to make my whole blog just one HTML file, one that would navigate from blog-post to blog-post by toggling element-visibility depending on the URL-fragment. This `Makefile` does the job.


## License

GPL v3.0


## Usage

You should probably not use this. But if you must, well, it's a makefile!

```bash
$ make init TITLE=my-blog-title
Done
$ make
- build/styles.css
- .sections/about.html
- .sections/post.html
- .sections/toc.html
- build/index.html
Done
$ # Serve the contents of `build` at `localhost:3948`
$ make serve
Serving HTTP on 0.0.0.0 port 3948 (http://0.0.0.0:3948/) ...
^C
Keyboard interrupt received, exiting.

$ make clean
- Removing .templates
- Removing .sections
- Removing build
```

The `make init TITLE={new title}` command initialises a blog. The variable `TITLE` inside of the Makefile will get overwritten, and then directories will be made with basic content:

```
|- source/
|   |- styles.css
|   |- about.md
|   '- post.md
'- media/
    | (empty)
```

Blog posts are written in markdown (`.md`) and placed in the `source` directory, with a metadata-block containing the three fields `date`, `title`, `summary`, where only `title` needs to be non-empty.

```markdown
---
date: "2020-02-02"
title: "Here goes the header (no need to add it again below)"
summary: "This summary will appear in the index of the page, i.e. the table-of-contents."
...

Here goes the blog-post itself
```

Posts without a `date` field, such as the `about.md` file, are sorted to the top of the post-history.

To include media in a blog post, like images, place them in the `media` directory, and add links to them as if they were located at the URL of the blog. So, a file `media/image.png` can be linked to in the blogposts by the url `https://blog-url.com/image.png`.

The Makefile creates a new directory `build/`, to contain the finished blog, ready to be hosted as a static webpage. It also relies on a couple of help-directories during the build, namely `.sections/` and `.templates`, so that the project will in full look like this:

```
|- .sections/
|   |- about.html
|   '- post.html
|- .templates/
|   |- section.html
|   '- toc.html
|- build/
|   |- index.html
|   '- styles.css
|- source/
|   |- styles.css
|   |- about.md
|   '- post.md
'- media/
    | (empty)
```
