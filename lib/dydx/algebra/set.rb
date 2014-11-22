require 'dydx/algebra/operator/parts/base'
require 'dydx/algebra/operator/parts/general'
require 'dydx/algebra/operator/parts/formula'
require 'dydx/algebra/operator/parts/inverse'
require 'dydx/algebra/operator/parts/num'

require 'dydx/algebra/operator/inverse'
require 'dydx/algebra/operator/formula'
require 'dydx/algebra/operator/num'
require 'dydx/algebra/operator/general'

require 'dydx/algebra/formula'
require 'dydx/algebra/inverse'

module Dydx
  module Algebra
    module Set
      module Base
        include Helper

        # TODO: Pi should not have attr_accessor
        def self.included(_klass)
          attr_accessor :n, :x
          alias_method :d, :differentiate
        end

        def initialize(x = nil)
          case self
          when Num
            @n = x
          when Sin, Cos, Tan, Log, Log10, Log2
            @x = x
          end
        end

        def to_s
          case self
          when Num   then n.to_s
          when Pi    then 'pi'
          when E     then 'e'
          when Sin   then "sin( #{x} )"
          when Cos   then "cos( #{x} )"
          when Tan   then "tan( #{x} )"
          when Log   then "log( #{x} )"
          when Log10 then "log10( #{x} )"
          when Log2  then "log2( #{x} )"
          end
        end

        def to_f
          case self
          when Num    then n.to_f
          when Pi     then Math::PI
          when E      then Math::E
          when Symbol then fail ArgumentError
          when Sin    then Math.sin(x.to_f)
          when Cos    then Math.cos(x.to_f)
          when Tan    then Math.tan(x.to_f)
          when Log    then Math.log(x.to_f)
          when Log10  then Math.log(x.to_f, 10)
          when Log2   then Math.log(x.to_f, 2)
          end
        end

        def subst(hash = {})
          case self
          when Num, Pi, E
            self
          when Symbol
            hash[self] || self
          when Sin    then sin(x.subst(hash))
          when Cos    then cos(x.subst(hash))
          when Tan    then tan(x.subst(hash))
          when Log    then log(x.subst(hash))
          when Log10  then log10(x.subst(hash))
          when Log2   then log2(x.subst(hash))
          end
        end

        def differentiate(sym = :x)
          case self
          when Num, Pi, E then e0
          when Symbol     then self == sym ? e1 : e0
          when Sin        then cos(x) * x.d(sym)
          when Cos        then -1 * sin(x) * x.d(sym)
          when Tan        then 1 / (cos(x) ** 2)
          when Log        then x.d(sym) / (x)
          when Log10      then x.d(sym) / (x * log(10))
          when Log2       then x.d(sym) / (x * log(2))
          end
        end

        def integrate(sym=:x)
          case self
          when Num, Pi, E then sym * self
          when Symbol     then self == sym ? 1/2r * self ** 2 : sym + self
          when Sin        then self.x == sym ? -cos(sym) : (fail "Can't integrate #{self}")
          when Cos        then self.x == sym ? sin(sym)  : (fail "Can't integrate #{self}")
          # when Tan        then 1 / (cos(x) ** 2)
          # when Log        then x.d(sym) / (x)
          # when Log10      then x.d(sym) / (x * log(10))
          # when Log2       then x.d(sym) / (x * log(2))
          end
        end
      end

      class Num
        include Base
        include Operator::Num
        %w(> >= < <=).each do |operator|
          define_method(operator) do |x|
            x = x.n if x.is_a?(Num)
            n.send(operator, x)
          end
        end
      end

      class Pi
        include Base
        include Operator::General
      end

      class E
        include Base
        include Operator::General
      end

      class Sin
        include Base
        include Operator::General
      end

      class Cos
        include Base
        include Operator::General
      end

      class Tan
        include Base
        include Operator::General
      end

      class Log
        include Base
        include Operator::General
      end

      class Log10
        include Base
        include Operator::General
      end

      class Log2
        include Base
        include Operator::General
      end

      Symbol.class_eval do
        include Base
        include Operator::General
      end

      numeric_proc = Proc.new do
        include Helper

        def subst(_hash = {})
          self
        end

        def differentiate(_sym = :x)
          e0
        end
        alias_method :d, :differentiate

        alias_method :addition, :+
        alias_method :subtraction, :-
        alias_method :multiplication, :*
        alias_method :division, :/
        alias_method :exponentiation, :**
        alias_method :modulation, :%

        ope_to_str = {
          addition: :+,
          subtraction: :-,
          multiplication: :*,
          division: :/,
          exponentiation: :**,
          modulation: :%
        }
        %w(+ - * / ** %).each do |operator|
          define_method(operator) do |g|
            if g.is_a?(Numeric)
              send(ope_to_str.key(operator.to_sym), g)
            else
              _(self).send(operator, g)
            end
          end
        end
        if self == Rational
          def to_s
            "( #{numerator} / #{denominator} )"
          end
        end
      end

      Float.class_eval(&numeric_proc)
      Fixnum.class_eval(&numeric_proc)
      Rational.class_eval(&numeric_proc)

      def e0
        eval('$e0 ||= _(0)')
      end

      def e1
        eval('$e1 ||= _(1)')
      end

      def pi
        $pi ||= Pi.new
      end

      def e
        $e ||= E.new
      end

      def oo
        Float::INFINITY
      end

      # TODO: Method has too many lines. [13/10]
      def log(formula)
        if formula.formula?(:*)
          f, g = formula.f, formula.g
          log(f) + log(g)
        elsif formula.formula?(:**)
          f, g = formula.f, formula.g
          g * log(f)
        elsif formula.one?
          e0
        elsif formula.is_a?(E)
          e1
        else
          Log.new(formula)
        end
      end

      def log2(formula)
        # TODO: refactor with log function.
        if formula.formula?(:*)
          f, g = formula.f, formula.g
          log2(f) + log2(g)
        elsif formula.formula?(:**)
          f, g = formula.f, formula.g
          g * log2(f)
        elsif formula.one?
          e0
        elsif formula.is_a?(Num)
          (formula.n == 2) ? e1 : log2(formula.n)
        elsif formula == 2
          e1
        else
          Log2.new(formula)
        end
      end

      def log10(formula)
        # TODO: refactor with log function.
        if formula.formula?(:*)
          f, g = formula.f, formula.g
          log10(f) + log10(g)
        elsif formula.formula?(:**)
          f, g = formula.f, formula.g
          g * log10(f)
        elsif formula.one?
          e0
        elsif formula.is_a?(Num)
          (formula.n == 10) ? e1 : log10(formula.n)
        elsif formula == 10
          e1
        else
          Log10.new(formula)
        end
      end

      # TODO: We should negative num
      def sin(x)
        return Sin.new(x) unless x.multiple_of?(pi) && (x / pi).num?

        radn = (x / pi)
        loop do
          break if radn < 2
          radn -= 2
        end

        case radn
        when 0        then 0
        when _(1) / 2 then 1
        when 1        then 0
        when _(3) / 2 then -1
        else               Sin.new(x)
        end
      end

      def cos(x)
        return Cos.new(x) unless x.multiple_of?(pi) && (x / pi).num?

        radn = (x / pi)
        loop do
          break if radn < 2
          radn -= 2
        end

        case radn
        when 0        then 1
        when _(1) / 2 then 0
        when 1        then -1
        when _(3) / 2 then 0
        else               Cos.new(x)
        end
      end

      def tan(x)
        if x == 0
          0
        else
          Tan.new(x)
        end
      end
    end
  end
end
