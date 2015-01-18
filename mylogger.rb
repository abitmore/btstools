#!/usr/bin/env ruby

######################
# logger

require 'logger'

class MultiLogger
    def initialize(*targets)
        @targets = targets
    end

    %w(log debug info warn error).each do |m|
        define_method(m) do |*args, &block|
            @targets.map { |t| t.send(m, *args, &block) }
        end
    end
end


$stderr_log = Logger.new(STDERR)
#$stdout_log = Logger.new(STDOUT)
$debug_file_log = Logger.new(File.open('logs/debug.log.'+Time.now.strftime('%Y%m%d%H'),'a'),shift_age = 'hourly')
$info_file_log = Logger.new(File.open('logs/info.log.'+Time.now.strftime('%Y%m%d'),'a'),shift_age = 'daily')
$error_file_log = Logger.new(File.open('logs/error.log.'+Time.now.strftime('%Y%m%d'),'a'),shift_age = 'daily')

$stderr_log.level = Logger::ERROR
#$stdout_log.level = Logger::INFO
$debug_file_log.level = Logger::DEBUG
$info_file_log.level = Logger::INFO
$error_file_log.level = Logger::ERROR

#$LOG = MultiLogger.new( $stderr_log, $stdout_log, $debug_file_log, $info_file_log, $error_file_log )
$LOG = MultiLogger.new( $stderr_log, $debug_file_log, $info_file_log, $error_file_log )

#$LOG = Logger.new STDOUT
#$LOG.level = Logger::INFO

