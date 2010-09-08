# -*- coding: utf-8 -*-

$KCODE ='u'
require 'mysql'

class MySQLWrapper

	DB_INFO = {:host=>"localhost",:user=>"root", ;password=>"hogehoge"}

	def self.connect arg
		begin
			db = Mysql::connect( arg[:host].to_s, arg[:user].to_s, arg[:password].to_s, arg[:db].to_s)
			yield MySQLWrapper.new( db)
		# 例外の救出
		rescue Mysql::Error => e
		 	p "[Error:#{e.errno}] #{e.error}"
		ensure
  			db.close if db
		end
	end

	def transaction
		return unless defined? yield
		begin
			@db.autocommit(true)
			@db.query('begin')
			yield
			@db.commit
		rescue Mysql::Error => e
  			p "[Error:#{e.errno}] #{e.error}"
			@db.rollback
		end
	end

	def initialize db
		@db = db
	end

	def execute sql, args={}
	  begin
		sql,param = prepare( sql, args)

	    stmt = @db.prepare sql
	    
	    eval( "stmt.execute #{@db.quote(param)}")
	  ensure
	    stmt.free_result if stmt
	    stmt.close if stmt
	  end
	end


	def insert_id
		@db.insert_id
	end
	def select_array( sql, args={}, &block)
	    select :array, sql, args, block
	end

	def select_hash( sql, args={}, &block)
	    select :hash, sql, args, block
	end

	def select_one_hash( sql, args={})
        objects = select_hash( sql, args)
        return nil if objects.length == 0
        objects[0]
    end
	
	def select_one_array( sql, args={})
        objects = select_array( sql, args)
        return nil if objects.length == 0
        objects[0]
    end

	def prepare( sql, args)
		params = sql.scan( /:([a-zA-Z0-9_]+)/).flatten.map {|param| param.intern}


		params.delete_if do |args_key|
			if args[args_key].nil?
				sql.gsub!( /:#{args_key}/, 'NULL')
				true
			else
				false
			end
		end


		sql.gsub!( /:[a-zA-Z0-9_]+/, '?')

		limit_sql, limit_arg = "",""

		unless args[:limit].nil? then
			if args[:limit].is_a?(Array) then
				if args[:limit].length == 1 then limit_sql, limit_arg = " limit ?",  " ,#{args[:limit][0]}" end
				if args[:limit].length > 1 then limit_sql, limit_arg = " limit ?,?", " ,#{args[:limit][0]},#{args[:limit][1]}" end
			else
				limit_sql, limit_arg = " limit ?",  " ,#{args[:limit]}"
			end
		end
	

		[sql + limit_sql, params.map {|param| args[param].nil? ? "'NULL'" : "'" + (args[param].to_s.gsub( /'/) { "\\'"}) + "'"}.join(',') + limit_arg]
	end

	def select( type, sql, args, block)

		begin
			sql,param = prepare( sql, args)

			stmt = @db.prepare sql
	    	eval( "stmt.execute #{param}")

	    	fields = stmt.result_metadata.fetch_fields if type == :hash
			
			if !block.nil?
				if type == :hash
					 stmt.each do |row|
						hash_row = {}
						fields.each_with_index {|field, index| hash_row[field.name.intern] = row[index]}
						block.call hash_row
					end
				else
					stmt.each { |row| block.call row}
	         	end
		     	return stmt.num_rows
			else
				rows = []
				if type == :hash
					stmt.each do |row|
						hash_row = {}
						fields.each_with_index {|field, index| hash_row[field.name.intern] = row[index]}
	                	rows << hash_row
				 	end
				else
					stmt.each { |row| rows << row}
				end
			end
	        return rows
		ensure
			stmt.free_result if stmt
			stmt.close if stmt
		end
	end

end
