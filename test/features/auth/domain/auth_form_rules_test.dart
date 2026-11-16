import 'package:calligro_app/features/auth/domain/auth_form_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('name (unchanged rules)', () {
    test('ok', () {
      for (final n in ['Ali', 'يزن قطوس', 'Şükrü 2', 'Yazan Qattous']) {
        expect(AuthFormRules.name(n), isNull, reason: n);
      }
    });
    test('problems', () {
      expect(AuthFormRules.name('  '), NameProblem.empty);
      expect(AuthFormRules.name('Al'), NameProblem.length);
      expect(AuthFormRules.name('A' * 51), NameProblem.length);
      expect(AuthFormRules.name('12345'), NameProblem.characters, reason: 'must contain a letter');
      expect(AuthFormRules.name('Ali!'), NameProblem.characters);
    });
  });

  group('email (THE BUG: real addresses were refused)', () {
    test('real addresses pass', () {
      for (final e in ['john_doe@gmail.com', 'a-b@my-school.edu.jo', 'x+y@z.academy', 'name.surname@mail.co.uk', ' ali@x.com ']) {
        expect(AuthFormRules.email(e), isNull, reason: e);
      }
    });
    test('not addresses', () {
      expect(AuthFormRules.email(''), EmailProblem.empty);
      for (final e in ['ali', 'ali@', '@x.com', 'ali@x', 'ali@x.c', 'a li@x.com', 'ali@@x.com', 'ali@x..com']) {
        expect(AuthFormRules.email(e), EmailProblem.format, reason: e);
      }
    });
  });

  group('password (THE BUG: strong passwords with other symbols were "too weak")', () {
    test('capital + digit + ANY symbol, 6+', () {
      for (final p in ['Abc@123', 'Abc#123', 'Abc.123', 'Pass_w0rd', 'Ünal#9x']) {
        expect(AuthFormRules.password(p), isNull, reason: p);
      }
    });
    test('problems', () {
      expect(AuthFormRules.password(''), PasswordProblem.empty);
      expect(AuthFormRules.password('Ab@1'), PasswordProblem.tooShort);
      expect(AuthFormRules.password('abc@123'), PasswordProblem.complexity, reason: 'no capital');
      expect(AuthFormRules.password('Abc@def'), PasswordProblem.complexity, reason: 'no digit');
      expect(AuthFormRules.password('Abc1234'), PasswordProblem.complexity, reason: 'no symbol');
      expect(AuthFormRules.password('Abc 123'), PasswordProblem.complexity, reason: 'a space is not a symbol');
    });
  });

  group('portfolio (unchanged rule)', () {
    test('links', () {
      expect(AuthFormRules.portfolio('https://behance.net/ali'), isNull);
      expect(AuthFormRules.portfolio('http://instagram.com/x?y=1'), isNull);
      expect(AuthFormRules.portfolio(''), PortfolioProblem.empty);
      expect(AuthFormRules.portfolio('behance.net/ali'), PortfolioProblem.format);
      expect(AuthFormRules.portfolio('https://localhost'), PortfolioProblem.format);
    });
  });
}
