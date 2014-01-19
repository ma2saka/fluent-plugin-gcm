guard :rake ,:task => 'test' do
  watch(%r{^lib/.+\.rb$})
  watch(%r{^test/.+\.rb$})
  notification :growl, sticky: true
end
