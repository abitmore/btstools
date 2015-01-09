#!/usr/bin/env ruby

######################
# logger

require 'logger'

$LOG = Logger.new STDOUT
$LOG.level = Logger::INFO

