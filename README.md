# letsencrypt-dnsimple

Quick hack to use the letsencrypt [DNS challenge](https://letsencrypt.github.io/acme-spec/#rfc.section.7.4) with dnsimple.

## Running (Ruby)

Requires Ruby 2.3.0.

```bash
$ gem install bundler
$ bundle install
$ DNSIMPLE_API_USER=you@foo.org \
  DNSIMPLE_API_TOKEN=... \
  NAMES=foo.org,www/foo.org \
  ACME_CONTACT=mailto:you@foo.org \
  bundle exec ruby main.rb
```

## Running (Docker)

Requires Docker (Ruby not required).

```bash
$ docker run \
  -e DNSIMPLE_API_USER=you@foo.org \
  -e DNSIMPLE_API_TOKEN=... \
  -e NAMES=foo.org,www/foo.org \
  -e ACME_CONTACT=mailto:you@foo.org \
  -v $(pwd)/live:/app/live \
  -ti meskyanichi/letsencrypt-dnsimple
```

## Result

`.pem` files will be written to files named after the value of `NAMES`, with the above config they would match `foo.org_www.foo.org-*`:

```
./live/foo.org_www.foo.org-cert.pem
./live/foo.org_www.foo.org-chain.pem
./live/foo.org_www.foo.org-fullchain.pem
./live/foo.org_www.foo.org-privkey.pem
```

## Config

Comes from the environment.

* `DNSIMPLE_API_USER` and `DNSIMPLE_API_TOKEN`: get these from https://dnsimple.com/user
* `NAMES`: a `,`-separated list of names that will be in the requested cert. Use `/` instead of `.` to denote the separation between subdomain and dnsimple domain. For example, to request a cert for `www.danp.net`, where `danp.net` is the domain dnsimple knows about, you'd use `www/danp.net`.
* `ACME_CONTACT`: the contact to use for [registration](https://letsencrypt.github.io/acme-spec/#rfc.section.6.3)
* `LETSENCRYPT_ENDPOINT`: optional, defaults to the production endpoint at `https://acme-v01.api.letsencrypt.org/`
