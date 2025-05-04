require 'pycall/import'
include PyCall::Import

pyimport :cowsay

puts cowsay.cow('Hello World')
