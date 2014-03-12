Pod::Spec.new do |s|
  s.name             = "RKData"
  s.version          = "0.0.1"
  s.summary          = "RKData - A generic/configurable data layer"
  s.description      = <<-DESC
                       =RKData
                       There are a lot of common patterns when it comes to getting data
                       from a server, caching it in memory and possibly on disk,
                       querying/modifying that data locally and syncing that back up to
                       the server.

                       It does not matter if you use a managed backend (e.g. Parse) or
                       you have your own server set-up, the client side code is still
                       basically the same. Furthermore, the programming model that Parse
                       in particular encourages is not one that I find satisfying. That
                       is not to knock on Parse, it is a perfectly reasonable model,
                       I just think a fully async model is more appropriate to iOS
                       development.

                       I also don't conceptually care what backend (if there is one at all)
                       is fulfilling data requests, I really care about what data I want.
                       The goal of this library is to abstract much of those problems.
                       Then, you should be able to plug and play any backend with minimal
                       changes to that actual code.

                       This is very much a work in progress, I wouldn't recommend
                       anyone else try to use it for a while, which should be noted
                       by the fact that this only exists in a private spec repo.
                       DESC
  s.homepage         = "https://github.com/rokob/RKData"
  s.license          = 'MIT'
  s.author           = { "Andrew Ledvina" => "wvvwwvw@gmail.com" }
  s.source           = { :git => "https://github.com/rokob/RKData.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/wolfgangfabian'

  s.platform     = :ios, '6.0'
  s.requires_arc = true

  s.source_files = 'RKData/RKData/**/*.{h,m}'

  s.public_header_files = 'RKData/**/*.h'
end
