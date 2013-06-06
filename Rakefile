require 'rubygems'
require 'rake/gempackagetask'
require 'yard'
require './lib/dyi'

task :default => [:package, :yard]

spec = Gem::Specification.new{|s|
  s.name = 'dyi'
  s.version = DYI::VERSION
  s.date = Gem::Specification::TODAY
  s.license = 'GPL-3'
  s.summary = '2D graphics library'
  s.description = <<-EOF
    DYI is a 2D graphics library, very rich and expressive.
    DYI have been optimized for SVG format, but it is also possible
    to output other format; for example, EPS.
  EOF

  s.authors = ['Mamoru Yuo']
  s.email = 'dyi_support@sound-f.jp'
  s.homepage = 'http://open-dyi.org/'

  s.required_ruby_version = '>= 1.8.7'

  s.files = Dir.glob('**/*')
  s.files.delete(File.basename(__FILE__))
  s.files.delete("yard_extensions.rb")
  s.files.reject!{|path|
    path =~ /^examples\/output\// || path =~ /^pkg\//
  }
  s.test_files = Dir.glob('test/*.rb')
}

# Defines `package' task
Rake::GemPackageTask.new(spec){|pkg|
  pkg.need_zip = true
  pkg.need_tar_gz = true
}

# Defines `yard' task
YARD::Rake::YardocTask.new{|yard|
  yard.options << "--title"
  yard.options << "DYI #{DYI::VERSION} Documents"
}
