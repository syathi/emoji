$code = ''
$source = [""]
$keywords = {
	'+'  => :add,
	'-'  => :sub,
	'*'  => :mul,
	'/'  => :div,
	'%'  => :mod,
	':=' => :asgn,
	'('  => :lpar,
	')'  => :rpar,
	'{'  => :lbra,
	'}'  => :rbra,
	'||' => :or,
	'&&' => :and,
	'>'  => :gre,
	'<'  => :les,
	'>=' => :greq,
	'<=' => :leseq,
	'==' => :eq,
	'!=' => :neq,
	'!'  => :not,
	'"' => :dblqte,
	'\'' => :qte,
	'🍴' => :if,
	'🍤' => :loop,
	'🍣' => :print,
	'🍕' => :println,
	'🍢' => :decl
}

$var = {} #変数のハッシュリスト、宣言されたらどんどん追加していく

def get_token()
	matchKeywords = /\s*(#{$keywords.keys.map{|t|Regexp.escape(t)}.join('|')})/
	matchVar      = /\s*(#{$var.keys.map{|t|Regexp.escape(t.to_s)}.join('|')})/ 
	matchStr      = /\s*\"/ || $code =~ /\s*\'/ 
	matchNum      = /\s*([0-9.]+)/
	if $code =~ /\A#{matchKeywords}/
		$code = $' 
		return $keywords[$1]
	elsif $code.index(":=")
		pos = $code.index(":=")
		varName = $code.slice(0, pos).strip
		if( $keywords.has_value?(varName) || $var.has_value?(varName) || varName.index("\"") || varName.index("\'") )then
			return :bad_token
		end
		$code = $code.slice(pos, $code.length-1)
		return varName
	elsif $code =~ /\A#{matchNum}/
		$code = $'
		return $1.to_f
	elsif $code =~ /\A\s*\z/  #空白は無視
		return nil
	elsif $code =~  /\A#{matchStr}/
		return $code = $'
	elsif $code =~ matchVar      #定義済み変数
		$code = $'
		return $var[$1] 
	end
	return :bad_token
end

def unget_token(token)
	if token.is_a? Numeric
		$code = token.to_s + $code#数値は文字に直して後ろの残りの式と一緒に返す
	else
		#$keywordsにある文字だったらそれと残りの式、違ったらそのまんま
		$code = $keywords.key(token) ? $keywords.key(token) + $code : $code
	end
end

def expression()
	result = term
	while true
		token = get_token
		unless token == :add or token == :sub
			unget_token token
			break
		end
		result = [token, result, term]
	end
	return result
end

def term()
	result = factor
	while true
		token = get_token
		unless token == :mul or token == :div
			unget_token token
			break
		end
		result = [token, result, factor]
	end
	return result
end

#factorが予期するトークンは数値か−符号か開き括弧(
def factor()
	token = get_token
	minusflg = 1
	if token == :sub
		minusflg = -1
		token = get_token()
	end

	#####最初の文字をみる####
	if token.is_a? Numeric
		return token * minusflg
	elsif token.is_a? String
		return token
	elsif token == :lpar
		result = expression()
		unless get_token == :rpar
			raise Exception, "unexpected token"
		end
		return [:mul, minusflg, result]
	elsif token == :if && get_token == :lpar			#if文　  #fix: 複数行処理出来るようにする
		resCond = exprCond()#条件式を導出する
		unless (token = get_token) == :rpar #閉じてなかったら怒る
			raise Exception, "unexpected token, expected )"
		end
		unless get_token == :lbra
			# if( gets.chomp == "{")then #とりあえずREPLのときはこうする

			# else
				raise Exception, "unexpected token, expected {"
			# end
		end
		result = expression #次以降の命令文 :rbraがくるまでやる
		
		# while (token != :rbra) do
		# 	$code = gets.chomp
		# 	result = expression
		# 	results << result
		# end
		unless get_token == :rbra
			raise Exception, "unexpected token, expected }"
		end
		return [:if, :lpar, resCond, :rpar, :lbra, result, :rbra]

	elsif token == :loop && get_token == :lpar          #while文
		resCond = exprCond()
		unless ( token = get_token) == :rpar
			raise Exception, "unexpected token, expected )"
		end
		unless get_token == :lbra
			raise Exception, "unexpected token, expected {"
		end
		result = expression
		unless get_token == :rbra
			raise Exception, "unexpected token, expected }"
		end
		return [:loop, :lpar, resCond, :rpar, :lbra, result, :rbra]

	elsif token == :decl                                #変数宣言
		varName = get_token
		if( token == :dblqte || token == :qte || token.is_a?(Numeric) )then
			raise Exception, "unexpected token, expected variable name"
		end
		unless( (token = get_token) == :asgn )
			raise Exception, "unexpected token, expected ="
		end
		return [:decl, varName, :asgn, expression]
	elsif( token == :println && get_token == :lpar )
		result = expression
		unless (token = get_token) == :rpar
			raise Exception, "unexpected token, expected )"
		end
		return [:println, result]
	elsif( token == :print && get_token == :lpar )
		result = expression
		unless get_token == :rpar
			raise Exception, "unexpected token, expected )"
		end
		return [:print, result]
	elsif token == :qte                                 #文字列
		pos = $code.index("\'")
		if pos then
			ret = $code.slice(0, pos).strip
			$code = $code.slice(pos+1, $code.length-1)
			return ret
		else
			raise Exception, "unexpected token, expected \'"
		end
	elsif token == :dblqte                              #文字列
		pos = $code.index("\"")
		if pos then
			ret = $code.slice(0, pos).strip
			$code = $code.slice(pos+1, $code.length-1)
			return ret
		else
			raise Exception, "unexpected token, expected \""
		end
	elsif token == nil
	else
		raise Exception, "unexpected token"
	end
	######################
end

def exprCond()
	result = termCond
	while true
		token = get_token
		unless token == :gre or token == :les or token == :greq or token == :leseq or token == :eq or token == :neq
			unget_token token
			break
		end
		result = [token, result, termCond]
	end
	return result
end

def termCond()
	result = factCond
	while true
		token = get_token
		if token == :add or token == :sub or token == :mul or token == :div or token == :mod
			#条件式の中に四則演算が来た時の処理
			#resultの配列の[2]にこの結果が入って返せるようにする return [token, result, hogehuga]
			unget_token token
			$code = result.to_s + $code
			return exprCalc
		end
		unless token == :and or token == :or
			unget_token token
			break
		end
		result = [token, result, factCond]
	end

	return result
end

def factCond()
	token = get_token
	notflg = true
	if token == :not
		minusflg = false
		token = get_token()
	end

	#####最初の文字をみる####
	#変数、値、bool値, 文字列かの判定
	if (token =~ /#{$var.values.map{|t|Regexp.escape(t.to_s)}.join('|')}/ || token.is_a?(Numeric) || !!token == token || token.is_a?(String) )then
		return notflg && token
	elsif token == :lpar
		result = expression()
		unless get_token == :rpar
			raise Exception, "unexpected token, expected )"
		end
		return [:and, notflg, result]
	else
		raise Exception, "unexpected token"
	end
	######################
end

def exprCalc()
	result = termCalc
	while true
		token = get_token
		unless token == :add or token == :sub
			unget_token token
			break
		end
		result = [token, result, termCalc]
	end
	return result
end

def termCalc()
	result = factCalc
	while true
		token = get_token
		unless token == :mul or token == :div
			unget_token token
			break
		end
		result = [token, result, factCalc]
	end
	return result
end

def factCalc()
	token = get_token
	minusflg = 1
	if token == :sub
		minusflg = -1
		token = get_token()
	end
	p $code
	#####最初の文字をみる####
	if token.is_a? Numeric
		return token * minusflg
	elsif token == :lpar
		result = expression()
		unless get_token == :rpar
			raise Exception, "unexpected token, expected )"
		end
		return [:mul, minusflg, result]
	elsif token == :qte
	elsif token == :dblqte
	else
		raise Exception, "unexpected token"
	end
	######################
end

def eval(exp)
	if exp.instance_of?(Array)
		case exp[0]
		when :add
			return eval(exp[1]) + eval(exp[2])
		when :sub
			return eval(exp[1]) - eval(exp[2])
		when :mul
			return eval(exp[1]) * eval(exp[2])
		when :div
			return eval(exp[1]) / eval(exp[2])
		when :or
			return eval(exp[1]) || eval(exp[2])
		when :and
			return eval(exp[1]) && eval(exp[2])
		when :eq
			return eval(exp[1]) == eval(exp[2])
		when :neq
			return eval(exp[1]) != eval(exp[2])
		when :if 
			process = exp[5]
			if( eval(exp[2]) )then
				eval(process)
			end
		when :loop
			process = exp[5]
			while ( eval(exp[2]) )do
				eval(process)
			end
		when :decl
			$var[exp[1]] = eval(exp[3])
		when :println
			p eval(exp[1])
		when :print
			print eval(exp[1])
		end
	else
		return exp
	end
end
if( ARGV[0] )then
	File.open(ARGV[0], "r")do |f| 
		f.each_line{ |li|
			$code = li
			if $code == "quit\n" || $code == "exit\n" then exit end
			ex = expression
			eval(ex)
		}
	end
else
	loop{#ARGF.readつかうと便利らしい
		print ">"
		$code = gets.chomp
		if $code == "quit" || $code == "exit" then exit end
		p eval(expression)
	}
end