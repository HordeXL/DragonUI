"""Point the README download button at the latest release's ZIP, whose name carries the version."""
import json
import os
import re
import sys
import urllib.error
import urllib.request

REPO = os.environ.get("GITHUB_REPOSITORY", "NeticSoul/DragonUI")
TOKEN = os.environ.get("GITHUB_TOKEN", "")
TAG = re.compile(r"v[0-9]+(\.[0-9]+)*")
LINK = re.compile(r"https://github\.com/" + re.escape(REPO) + r"/releases/download/[^/\s\"()]+/[^/\s\"()]+\.zip")


def latest_release():
    request = urllib.request.Request(
        f"https://api.github.com/repos/{REPO}/releases/latest",
        headers={"Accept": "application/vnd.github+json", "User-Agent": "dragonui-download-link"},
    )
    if TOKEN:
        request.add_header("Authorization", "Bearer " + TOKEN)
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def downloads(url):
    request = urllib.request.Request(url, method="HEAD", headers={"User-Agent": "dragonui-download-link"})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.status == 200
    except urllib.error.URLError:
        return False


def zip_url(release):
    tag = release["tag_name"]
    if not TAG.fullmatch(tag):
        sys.exit(f"Unexpected tag: {tag!r}")
    name = f"DragonUI-{tag[1:]}.zip"
    if not any(asset["name"] == name and asset["state"] == "uploaded" for asset in release["assets"]):
        sys.exit(f"{tag} has no {name}")
    return f"https://github.com/{REPO}/releases/download/{tag}/{name}"


def main(path="README.md"):
    release = latest_release()
    published = os.environ.get("RELEASE_TAG", "")
    if published and published != release["tag_name"]:
        sys.exit(f"{published} was published, but the latest release is {release['tag_name']}")

    url = zip_url(release)
    with open(path, encoding="utf-8", newline="") as file:
        text = file.read()
    links = LINK.findall(text)
    if len(links) != 1:
        sys.exit(f"Expected one release link in {path}, found {len(links)}")
    if links[0] == url:
        print("Already up to date:", url)
        return
    if not downloads(url):
        sys.exit(f"Does not download: {url}")

    with open(path, "w", encoding="utf-8", newline="") as file:
        file.write(text.replace(links[0], url))
    print("Updated to", url)


if __name__ == "__main__":
    main()
