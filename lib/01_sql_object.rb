require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        #{self.table_name}
    SQL
    .first
    .map(&:to_sym)
  end

  def self.finalize!
    self.columns.each do |col|
      define_method(col) { self.attributes[col] }
      define_method(col.to_s + "=") { |val| self.attributes[col] = val}
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name || self.name.tableize
  end

  def self.all
    all_arr = DBConnection.execute(<<-SQL)
      SELECT
        #{table_name}.*
      FROM
        #{table_name}
    SQL

    self.parse_all(all_arr)
  end

  def self.parse_all(results)
    results.map do |result|
      self.new(result)
    end
  end

  def self.find(id)
    hash = DBConnection.execute(<<-SQL, id)
      SELECT
        #{table_name}.*
      FROM
        #{table_name}
      WHERE
        #{table_name}.id = ?
    SQL
    p hash
    parse_all(hash).first
  end

  def initialize(params = {})
    params.each do |name, val|
      raise "unknown attribute '#{name}'" unless self.class.columns.include?(name.to_sym)

      self.send(name.to_s + "=", val)
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.class.columns.map {|col| self.send(col) }
  end

  def insert
    question_marks = (["?"] * self.class.columns.length).join(", ")

    p question_marks

    DBConnection.execute(<<-SQL, *attribute_values)
      INSERT INTO
        #{self.class.table_name} (#{self.class.columns.join(', ')})
      VALUES
        (#{question_marks})
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update
    cols = self.class.columns.map {|col| "#{col} = ?" }.join(", ")
    DBConnection.execute(<<-SQL, *attribute_values, self.id)
      UPDATE
        #{self.class.table_name}
      SET
        #{cols}
      WHERE
        id = ?
    SQL
  end

  def save
    self.id.nil? ? self.insert : self.update
  end
end
