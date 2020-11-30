# Smorku
Smorku is a Roku application for browsing and viewing [SmugMug](https://www.smugmug.com) photo albums. 
It requires a Roku device with [development mode](https://developer.roku.com/docs/developer-program/getting-started/developer-setup.md) enabled and a SmugMug API key. This is not available in the Roku app store because Roku's app submission process would require me to set them up with a number of paid SmugMug accounts and since I'm not affiliated with SmugMug, that's not really feasible. 

## Running in dev mode
* Put your smugmug api key and api secret in the `json/apikeys.json` file. 
* Zip the smorku directory *without* a top level directory. E.g. `zip -r ../smorku.zip . -x ".git/*"` 
* Upload the zip file to your roku device using the developer web interface running on the roku device.

## Usage
If you have a SmugMug account, you can sign into it with Smorku using their OAuth process. If not, then you can just browse other users' albums using their smugmug username. When you start the login, you'll get a QR code with a link to SmugMug's 
OAUTH page. Scan the QR Code on your phone and login to smugmug where you'll get a 6 digit numeric code to enter into the Smorku app. Once that's done, 
the app is authorized to view your albums. 
You're then taken to a gallery screen with all of your albums. Selecting an album naturally takes you to the photos and videos in that album which you can scroll through and select to view full screen. In full screen mode you can use the left and right buttons on the remote to navigate around your photos. This is great for 
~~boring~~ entertaining your friends and family with vacation photos. 

You can also browse other users' public albums by pressing the * button and entering a user's smugmug name. You can also start this way and enter a user's smugmug name
without logging in when first launching the app. 

## Implementation details
Roku development happens in their programming language called BrightScript, which is loosely based on Visual Basic. Smorku is based on their SceneGraph framework 
which does some of the basic layout and styling in XML, and has the application login in brightscript either referenced from the XML or embedded in it for small stuff.

Smorku uses [SmugMug's API](https://api.smugmug.com/api/v2/doc) to interact with the smugmug service. This uses an OAuth 1.0a mechanism to authenticate the user, which
poses some interesting challenges on Roku. We have to use their out of band mechanism for authentication since Roku doesn't have a browser or any sort of HTML display capability. This involves showing a URL to the user and having them enter it into a browser to authenticate there and get a code to enter into the application. Unfortunately,
this URL is ridiculously long with huge tokens and secrets in it, so it's not suitable for manual transcription. In order to make this work, we'll need to generate a QR 
code with the login URL. I didn't want to rely on some web service for this, so I implemented a QR code generator in brightscript.

### QR Codes
The qr code implementation lives in the `qrview.brs` file, which provides a widget for displaying text qr codes. It's implementation is based on [python-qrcode](https://github.com/lincolnloop/python-qrcode). 
The code is rendered as a 2 dimensional array of rectangles representing the bit values of the QR Code. First we calculate what version (basically what size) QR code we need given the length of the text we're trying to show. This lets us know what how many bit values we need to have. First up we draw all of the constant areas of the QR code.
There's the iconic positioning markers, the squares within squares at three corners of the area, which I think even humans use to identify a QR code as a QR code.
Then there's position adjustment markers, which are smaller markers to help with aligning the image on reading. And there are timing patterns, which are lines between the inner corners of the positioning markers that alternate on and off, which help identify the size of the grid.
Finally in the area between the position markers, the QR version and type info gets encoded.
The remaining area is filled with the data and Reed Solomon error correction blocks starting in the bottom right corner and zig zagging up and to the left. One of a number of pre-defined masks is applied to this in order to prevent long sections of repeated patterns. In a better implementation of this, each of the pre-defined masks would be tested to see which one produced the fewest of these artifacts, but when displaying on a TV, we can be assured of a good quality image with no errors, so I didn't bother.
On the roku, this is rendered as an array of rectangle objects drawn on the screen on top of an outer rectangle. 

### Login 
SmugMug uses OAuth 1.0a for authorizing API clients to an account. OAuth 1.0 uses an API key and secret provided by SmugMug to the application author, which are not included here of course, in order to identify the clients. Since OAuth 1.0 doesn't require requests to happen over HTTPS, the secret is used to sign request data to prove that the request came from a client. OAuth 2.0 on the other hand, requires HTTPS and controversially just puts the secret in the query parameters, but that's another story. 
First we get request a token from SmugMug after telling it what type of access we're requesting, in this case Full access to the account data, but read only. 
The token response lets us build the authorization URL that we're going to put into a QR code to send the user to. Once the user completes the authorization on their phone, they get a six digit code to enter into the Smorku app. Once we have that code, we call smugmug again with that in order to get an access token that store in the roku app preferences which we'll use for all subsequent requests.

### API Usage
Smorku's usage of the SmugMug API is pretty straightforward. In `UriFetcher.brs` there is a common pool of Roku's http clients with a request queue and a callback model. This is important as some operations wind up resulting in a lot of calls to the API. For example if you ask about the data for an Album, you'll get some basic info about the album, e.g. title, timestamps, image counts, web interface URL, etc. You'll also get a list of URLs you can use to get more specific info, like the list of images, comments, pricing info, etc. SmugMug has a clever "expand" option in their API that allows you to request any of those sub URLs in the response to be filled in so we don't have to create storms of requests to get all of the data that we need. You can even expand on expansions, which is a feature we use in a number of places, for example when getting the list of albums, we expand out the "Highlight Image" to show a thumbnail in the album grid, but we need to get the right image size for that, so we load that image's image sizes URI, then we need to get a custom one to fit the size of the grid. 

In order to keep the interface as snappy possible, when we get the list of images for an album, we get URLs for both the thumbnail size and for the full screen sized image. Roku also automatically caches images that are loaded into one of it's Poster elements (basically an image canvas.) We take advantage of this in the full screen image viewer to keep things responsive by using three different posters that we swap between. We have the one that we're currently showing, then a hidden poster with one that may or may not be currently loading, then a hidden one that has the next image in the album in whatever direction the user last moved so that it's ready to go if they keep going in that direction.

