# HaptiBraille website (web-intro-v3)

The public website for HaptiBraille. It explains the project in eight chapters and lets visitors
download the Android app.

## Pages

| Page | File |
|---|---|
| Landing page: download button, live "Feel it" demo, chapter list, install steps | `index.html` |
| 1. The problem | `problem.html` |
| 2. The solution | `solution.html` |
| 3. Who it's for | `audience.html` |
| 4. Why we're doing this | `why.html` |
| 5. What inspired us | `inspiration.html` |
| 6. How it works | `how.html` |
| 7. What we're building | `what.html` |
| 8. The tech stack | `tech.html` |

## What's special

- **Download button** links to `main-v1/release/HaptiBraille.apk` in this repo. GitHub serves it as a
  file download, so tapping it on an Android phone downloads the app directly.
- **Live "Feel it" demo**: type a word and watch a Braille cell play it dot by dot, with a timeline strip.
  On Android in Chrome the phone actually vibrates the Braille (Web Vibration API), using the same
  timing rules as the app. Other browsers show the animation only.
- **Background**: a canvas field of dots that ripple like vibrations from the cursor, taps and clicks.
- **Cursor**: a ring follows the pointer and turns into a Braille cell over buttons and links. The normal
  cursor is never hidden.
- **Scroll**: content fades in as you scroll and chapter numbers (written in Braille) tap their dots in.
  The chapter bar at the top fills as you read.
- **Accessible**: skip link, visible keyboard focus, screen-reader labels, high contrast, and every
  animation switches off when the device's "reduce motion" setting is on.

## Run it

No build step and no dependencies. Open `index.html` in a browser, or serve the folder:

```
npx serve .
```

## Publish it with GitHub Pages

Repository **Settings → Pages → Deploy from a branch → `main`**, folder `/ (root)`. The site will then
be at `https://<user>.github.io/HaptiBraille/web-intro-v3/`.

## Files

```
index.html, problem.html, … tech.html   the nine pages
assets/css/site.css                     all styles (colour tokens at the top)
assets/js/site.js                       dot field, cursor, scroll reveal, Braille cells, the demo
assets/img/favicon.svg                  icon: the Braille letter h
```

Fonts: Bricolage Grotesque (headings) and Atkinson Hyperlegible (text), from Google Fonts.
