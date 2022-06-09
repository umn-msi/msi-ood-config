OodFilesApp.candidate_favorite_paths.tap do |paths|

    add_paths = User.new.groups.map { |group| "/home/#{group}" }
    add_paths.concat ["/scratch.global", "/scratch.global/#{User.new.name}"]

    paths.concat add_paths.map { |p| FavoritePath.new(p) }

end
