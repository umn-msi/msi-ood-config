Rails.application.config.after_initialize do
  class PosixFile
    def self.num_files(from, names)
      names.map do |name|
        path = Pathname.new(Pathname.new(from).join(name))
        if path.file? || path.symlink?
          1
        elsif path.directory?
          Dir.glob("#{path}/**/*", File::FNM_DOTMATCH).length
        else
          # not real?
          0
        end
      end.sum
    end
  end
end
