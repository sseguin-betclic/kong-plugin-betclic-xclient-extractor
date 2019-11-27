# kong-plugin-betclic-xclient-extractor

A Kong plugin that will extract Betclic X-CLIENT claims to convert them to headers.

## How it works
When enabled, this plugin will verify the signature, the validity of the token and the expiry date.
Then the plugin can either extract claims from the token to add them to headers or to the backend URI.

This plugin can also be used in conjunction with other Kong plugins like Rate limiting etc.



## Installation - Betclic Internal

Kong plugins are now deployed automatically on the API gateway front and back to `dev`, `stage1` and `stage2`. The deployment to production is managed by a manual promote.

To enable the plugin, it needs to be added to the `plugins.yml` file on the API gateway back or front

```bash
plugins:
  - name: betclic-xclient-extractor
    git: git@github.com:betclicgroup/kong-plugin-betclic-xclient-extractor.git
```

