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

  def self.next_maintenance
    now = Time.now
    maint = Time.new(now.year, now.month, now.day)

    while maint.day > 7 or (maint.day <= 7 and maint.wday > 3)
        maint += 86400
    end

    return maint
  end

  quick_resources = {
    # Format is partition:nodes:ntasks-per-node:memory:tmp:gpus
    common: [
      
    ],
    mesabi: [
      ['Interactive - 3 cores, 8 GB, 48 GB local scratch', 'interactive:1:3:8:48:0'],
      ['Big Mem - 12 cores, 128 GB, 180 GB local scratch', 'bigmem:1:12:128:180:0'],
      ['K40 GPU - 12 cores, 60 GB, 100 GB local scratch, 1 K40', 'k40:12:60:100:1'],
    ],
    agate: [
      ['Interactive - 2 cores, 32 GB, 64 GB local scratch', 'interactive:1:2:32:64'],
      ['Big Mem - 32 cores, 500 GB, 190 GB local scratch', 'ag2tb:1:32:500:190'],
    ],
  }
  
  partitions = { 
    common: [
      ['interactive', 'interactive'],
      ['interactive-gpu', 'interactive-gpu'],
      ['preempt', 'preempt'],
      ['preempt-gpu', 'preempt-gpu'],
      ['interactive-long', 'interactive-long'],
    ],
    mesabi: [
      ['small', 'small'],
      ['large', 'large'],
      ['amdsmall', 'amdsmall'],
      ['amdlarge', 'amdlarge'],
      ['amd512', 'amd512'],
      ['amd2tb', 'amd2tb'],
      ['v100', 'v100'],
    ],
    agate: [
      ['agsmall', 'agsmall'],
      ['aglarge', 'aglarge'],
      ['ag2tb', 'ag2tb'],
      ['a100-4', 'a100-4'],
      ['a100-8', 'a100-8'],
    ],
  }


end
