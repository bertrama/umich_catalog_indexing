require 'jdbc-helper'
require_relative 'ht_secure_data'
require_relative "mysql-connector-java-5.1.17-bin.jar"

module HathiTrust
  class PrintHoldings
    extend HathiTrust::SecureData
    
    def self.get_print_holdings_hash(htids)
      htids = Array(htids)
      Thread.current[:phdbdbh] ||= JDBCHelper::Connection.new(
                    :driver=>'com.mysql.jdbc.Driver',
                    :url=>'jdbc:mysql://' + self.db_machine + '/' + self.db_db,
                    :user => self.db_user,
                    :password => self.db_password
                  )
                  
      query = "select volume_id, member_id from holdings_htitem_htmember where volume_id IN (#{self.commaify(htids)})"
      
      
      htid_map = {}
      Thread.current[:phdbdbh].query(query).each do |pair|
        htid, inst = *pair
        htid_map[htid] ||= []
        htid_map[htid] << inst
      end
      
      htid_map
    end
    
  
    
    # A simple "commaify" to (naively) quote values and make a list for SQL "IN"
    # NOT SAFE for general data, but just fine for HathiTrust IDs, which have no 
    # double-quotes in them.
    
    def self.commaify(a)
      a = Array(a)
      return a.map{|v| "\"#{v}\""}.join(', ')
    end
    
  end
end

