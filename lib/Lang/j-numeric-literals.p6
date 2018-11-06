#!/usr/bin/env perl6

# use Grammar::Tracer;
# use Grammar::Debugger;

grammar J-NUMERIC-LITERAL {
  # Whitespace-delimited vector of numeric atoms
  rule  TOP             {  <numeric-atom>* %% \s+                                              }

  # TODO: See if we can abstract the pattern `<super-type> = <sub-type> (<delimiter> <sub-type>)?`
  # so that, e.g. we could say rational = foo(<scientific>,/r/> etc.
  token numeric-atom    {  <val=decimal>                 [  b  <dig=alNUM>      ]? $<xtnd>=x?  }  # based constants, e.g. 16bFFFF
  token decimal         {  <val=complx>                  [ <P> <exp=complx>     ]?             }  # π- and e-notation, e.g. 2p1, 1e0.5
  token complx          {  <val=rational>                [ <J> <img=rational>   ]?             }  # e.g. 1j1, 2ar3, 4ad5
  token rational        {  <val=scientific>              [  r  <dnm=scientific> ]?             }  # e.g. 1r2, 22r7
  token scientific      {  <val=floating-point>          [  e  <exp=j-int>      ]?             }  # e.g. 1.234e_56

  # Either +Inf (_), -Inf (__), Nan (_.), or a simple floating point (-1234.56)
  regex floating-point  {  <neg>?$<mag>=[_ | <val=nn-int>[ '.' <mts=nn-int>     ]?] | <nan>    }

  # Positive integers & negation sign
  token j-int           {  <neg>?<val=nn-int>                                                  }
  token nn-int          {  <[0..9]>+                                                           }  # non-negative ints
  token neg             {  _                                                                   }
  token nan             { '_.'                                                                 }

  # Exponential and complex number delimiters, respectively
  token P               {  <[px]>                                                              }
  token J               {  [j|ar|ad]                                                           }

  # Digits in base 36 (all upper, unlike the official J interpreter)
  token alNUM           {  <[0..9]+[A..Z]>+                                                    }
}

class j-numeric-interpreter {

  method TOP($/) {
    $/.make(  @<numeric-atom>.map(*.made)  );
  }

  method numeric-atom($/) {
    #TODO: Explicitly handle eXtended integers when $<x>

    if not $<alNUM>:exists {
      $/.make(  $<val>.made  );
    } else {
     my $digits = join "", ('0'..'9'),('A'..'Z');
     my @digits = map {$digits.index($_)}, $<alNUM>.comb;
     $/.make(  [+] @digits Z* reverse flat 1 , [\*] $<val>.made xx @digits-1  );
    }
  }

  method decimal($/) {
    $/.make(  $<val>.made * (pi, e)['px'.index($<P> // 'p')] ** ($<exp>.made // 0)  );
  }

  method complx($/) {
    if not $<img>:exists {
       # Could avoid a branch with  real+($imaginary || 0)*i) but complex is a sticky, costly type.
       $/.make(  $<val>.made  );
    } else {
      my ($real, $img) = @<val img>.map(*.made);   # $<val>.made, $<img>.made;
      given $<J> {
        when "ad" { # (a)ngle in (d)egrees
          $img *= pi/180;
          proceed;  # permit fall-through
        }
        when "ad" | "ar" { # $/ is a read-only param; can't say rx/a./
          ($real, $img) = ($real,$real) Z* [.sin , .cos] with $img;
          proceed;
        }
        default {
	      $/.make(  $real + $img * i  );
        }
      }
    }
  }

  method rational($/) {
    # Easier but wasteful
    # $/.make(  Rat.new($<val>.made, $<dnm>.made || 1)  );

    $/.make(  $<dnm>:exists ?? Rat.new($<val>.made, $<dnm>.made) !! $<val>.made  );
  }

  method scientific($/) {
    $/.make($<val>.made * 10**($<exp>.made // 0));
  }

  method floating-point($/)  {
    my $val = $<val>.made // 0;

    given $<mag> // $<nan> {
      when '_.' {
        $val = NaN;
        succeed;
      }

      when '_' {
        $val = Inf;
        proceed;
      }

      default {
        # Mantissa; has no effect on Inf
        my $mts = $<mts> // "";
        $val += [+] $mts.comb Z* [\*] 0.1 xx $mts.chars;

        # Negation; this applies to Inf as well
        $val *= (-1) ** +?$<neg>;
      }
    }

    $/.make(  $val  );
  }

  method j-int($/)  {
    # Yes, leave the ()s around the -1
    $/.make(  $<val>.made * (-1) ** +?$<neg>  );
  }

  method nn-int($/) {
    # Secretly, you can Numify a Str with +, but let's do it the hard way.
    $/.make(  :10[map {'0123456789'.index($_)}, $/.comb]  );
  }

}

#####
# Go
#####
sub MAIN(Str $s) {
  my Match $m = J-NUMERIC-LITERAL.parse($s, :actions(j-numeric-interpreter.new));
  say $m.made;
}
