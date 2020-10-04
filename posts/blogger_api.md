Not sure if this is really post worthy but writing it down.

1. Sign up for Google Cloud Platform
2. Enable Blogger API: https://console.developers.google.com/apis/library/blogger.googleapis.com?filter=category:blog-cms&id=97b21ba4-1cd6-4e5c-969b-207c4d63b2cd
3. Create OAuth 2.0 client id credentials: https://console.developers.google.com/apis/api/blogger.googleapis.com/credentials

   API access must act as a user, so the app must direct the user to a browser to login, and listen on localhost to accept the redirect with authorization code.
4. Use one of the Google API client libraries (particularly for auth) to perform the authorization code flow.
5. You'll get back access and refresh tokens. Persist these tokens in secure storage. Reuse them the next time the app starts to avoid prompting for login every time.
