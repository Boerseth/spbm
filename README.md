# Single Page web-LOg SHell-script (splo.sh)
I wanted to make my whole blog just one HTML file, one that would navigate from blog-post to blog-post by toggling element-visibility depending on the URL-fragment. The script `splo.sh` does the job.


## License
GPL v3.0


## Usage
You should probably not use this.

But if you must:

1. Create blog entries in the form of markdown-files. They all must have a metadata-block at the top, like so:

```markdown
---
date: "2020-02-02"
title: "Here goes the header (no need to add it again below)"
summary: "This summary will appear in the index of the page, i.e. the table-of-contents."
...

Here goes the blog-post itself
```

2. Place all these blog-post-markdown-files in the same directory, e.g. `posts`.

2. Place any media you might want to host and link to from your page in a second directory, e.g. `media`.

4. Run the script with title, post-directory, and media-directory as options:

```bash
$ ./splo.sh -t Frode -p posts -m media
```
