#!/usr/bin/env rundklet
add_note <<~Note
  https://www.vaultproject.io/docs/audit/index.html
  TODO log center, no log rotate
Note

custom_commands do
  desc '', ''
  option :raw, type: :boolean, banner: 'raw log?'
  def enable_file_audit
    is_raw = !!(env =~ /^dev/)
    is_raw = options[:raw] if options.key?(:raw)

    container_run <<~Desc
      vault login #{root_token}
      vault audit disable file
      vault audit enable file log_raw=#{is_raw} file_path=stdout
      vault audit list
    Desc
  end

  desc '', ''
  def list_audit
    container_run <<~Desc
      vault login #{root_token}
      vault audit list
    Desc
  end

  no_commands do
  end
end

__END__

* Multiple audit devices can be enabled and Vault will send the audit logs to both. This allows you to not only have a redundant copy, but also a second copy in case the first is tampered with.
* format: json
* hashed sensitive info by default
* If there are any audit devices enabled, Vault requires that at least one be able to persist the log before completing a Vault request.
  If you have only one audit device enabled, and it is blocking (network block, etc.), then Vault will be unresponsive. Vault will not complete any requests until the audit device can write.
  If you have more than one audit device, then Vault will complete the request as long as one audit device persists the log.
