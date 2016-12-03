require "openssl"
require "shellwords"

require "dnsimple"
require "acme/client"

DEFAULT_LETSENCRYPT_ENDPOINT = "https://acme-v01.api.letsencrypt.org/"
LETSENCRYPT_NAME = "_acme-challenge" # paranoid, don't use value from acme client
LETSENCRYPT_NAME_TYPE = "TXT" # paranoid, don't use value from acme client
DNSIMPLE_TTL = 60

raw_names = ENV.fetch("NAMES").split(",")
authorize_names = raw_names.inject({}) {|h, rn| n = rn.sub("/", "."); d = rn.split("/", 2).last; h.update(n => d) }

dnsimple = Dnsimple::Client.new(username: ENV.fetch("DNSIMPLE_API_USER"), api_token: ENV.fetch("DNSIMPLE_API_TOKEN"))
domains = authorize_names.values.uniq.inject({}) {|h, d| h.update(d => dnsimple.domains.domain(d)) }

private_key = OpenSSL::PKey::RSA.new(2048)
acme = Acme::Client.new(private_key: private_key, endpoint: ENV.fetch("LETSENCRYPT_ENDPOINT", DEFAULT_LETSENCRYPT_ENDPOINT))

registration = acme.register(contact: ENV.fetch("ACME_CONTACT"))
registration.agree_terms

authorize_names.each do |authorize_name, authorize_domain_name|
  authorize_domain = domains.fetch(authorize_domain_name)
  authorization = acme.authorize(domain: authorize_name)

  challenge = authorization.dns01
  if challenge.record_name != LETSENCRYPT_NAME
    abort "acme wanted record name #{challenge.record_name}, expected #{LETSENCRYPT_NAME}"
  end
  if challenge.record_type != LETSENCRYPT_NAME_TYPE
    abort "acme wanted record type #{challenge.record_type}, expected #{LETSENCRYPT_NAME_TYPE}"
  end

  # full name to authorize
  letsencrypt_authorize_name = "#{LETSENCRYPT_NAME}.#{authorize_name}"
  # the name we care about at dnsimple
  dnsimple_authorize_name = letsencrypt_authorize_name.sub(/(\A|\.)#{Regexp.escape(authorize_domain.name)}\z/, "")

  puts "preparing to authorize #{authorize_name} via #{letsencrypt_authorize_name} with dnsimple record #{dnsimple_authorize_name}/#{authorize_domain.name}"

  dnsimple.domains.records(authorize_domain.id).select do |record|
    record.name == dnsimple_authorize_name && record.type == LETSENCRYPT_NAME_TYPE
  end.each do |existing_record|
    puts "deleting existing record: #{existing_record.name} #{existing_record.type} #{existing_record.content}"
    dnsimple.domains.delete_record(authorize_domain.id, existing_record.id)
  end

  puts "creating new record: #{dnsimple_authorize_name} (#{authorize_domain.name}) #{LETSENCRYPT_NAME_TYPE} #{challenge.record_content}"

  dnsimple.domains.create_record(
    authorize_domain.id,
    name: dnsimple_authorize_name,
    record_type: LETSENCRYPT_NAME_TYPE,
    content: challenge.record_content,
    ttl: DNSIMPLE_TTL)

  puts "waiting for record to be at dnsimple servers"
  loop do
    system("dig @ns1.dnsimple.com #{Shellwords.escape(letsencrypt_authorize_name)} txt | grep -e #{Shellwords.escape(challenge.record_content)}")
    break if $?.success?
    sleep 5
  end

  puts "sleeping for ttl #{DNSIMPLE_TTL} seconds"
  sleep(DNSIMPLE_TTL)

  puts "requesting verification"
  challenge.request_verification

  puts "waiting for verification..."
  loop do
    if challenge.verify_status == "valid"
      puts "valid"
      break
    end

    if challenge.error
      abort "challenge error: #{challenge.error}"
    end

    sleep 5
  end
end

filename_base = ENV["OUTPUT_FILE_BASE"] || authorize_names.keys.sort.join("_")

csr = Acme::Client::CertificateRequest.new(names: authorize_names.keys)

puts "requesting certificate"
certificate = acme.new_certificate(csr)

File.write("#{filename_base}-key.pem", certificate.request.private_key.to_pem)
File.write("#{filename_base}-cert.pem", certificate.to_pem)
File.write("#{filename_base}-chain.pem", certificate.chain_to_pem)
File.write("#{filename_base}-fullchain.pem", certificate.fullchain_to_pem)
