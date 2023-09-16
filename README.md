This is a project that I am currently working on, that updates Keywords to an album in Smugmug.com, using the everypixel.com AI API
There are 2 versions

update_keywords.py - written in Python
update_keywords.ps1- written in Powershell as a learning exercise, I won't update this.

How it works right now (Python version):

By having the approrpriate Smugmug album selected in the code, and the appropriate API keys entered,
it runs over that Album, passes each image to everypixel, and then updates the image with AI generated keywords

Plans for the Python project:

1. Allow the user to select a SMugmug ALbum
2. Alow the user to confirm the keywords - A single album will likely have a lot of similar keywords. Some keywords can be inappropriate
3. Looking for way to create an app, and have it avaialble to many users.