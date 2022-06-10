require 'yaml'

class MSI

  def self.accounts_cache_path
    return "#{Dir.home}/ondemand/accounts.cache"

  end

  def self.accounts_refresh
    Rails.logger.info("accounts_refresh")

    accounts_raw = %x[sacctmgr --noheader show assoc user="#{User.new.name}" format=account]
    if not $?.success?
      Rails.logger.warn("Failed to query SlurmDB for accounts")
      return []

    end

    accounts = accounts_raw.split("\n").uniq().map { |account| account.strip }
    File.write(self.accounts_cache_path, accounts.to_yaml)

    return accounts

  end

  def self.accounts
    if File.exist?(self.accounts_cache_path) and File.mtime(self.accounts_cache_path) > Time.now - 900
      return YAML.load_file(self.accounts_cache_path)

    end

    return self.accounts_refresh

  end

end
