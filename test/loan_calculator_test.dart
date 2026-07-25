import 'package:emprestafacil/core/utils/loan_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Penhor', () {
    test('juros = capital * taxa/100', () {
      expect(LoanCalculator.pledgeInterest(1000, 10), 100.0);
      expect(LoanCalculator.pledgeInterest(2500, 8), 200.0);
    });
  });

  group('Diário', () {
    test('valor por dia = capital * taxa/100, repetido a cada dia', () {
      final s = LoanCalculator.dailySchedule(
        capital: 1000,
        ratePercent: 6,
        termDays: 20,
        startDate: DateTime(2025, 1, 1),
      );
      expect(s.length, 20);
      // 6% de 1000 = 60 por dia
      expect(s.first.amount, 60.0);
      expect(s.last.amount, 60.0);
      // total = 60 * 20 = 1200
      expect(LoanCalculator.scheduleTotal(s), closeTo(1200, 0.001));
      // primeiro vencimento no dia seguinte
      expect(s.first.dueDate, DateTime(2025, 1, 2));
      expect(s.last.dueDate, DateTime(2025, 1, 21));
    });

    test('todos os dias têm o mesmo valor', () {
      final s = LoanCalculator.dailySchedule(
        capital: 777,
        ratePercent: 13,
        termDays: 7,
        startDate: DateTime(2025, 3, 10),
      );
      // 13% de 777 = 101.01 por dia
      expect(s.first.amount, closeTo(101.01, 0.001));
      final total = LoanCalculator.scheduleTotal(s);
      expect(total, closeTo(101.01 * 7, 0.001));
    });
  });

  group('Parcelado', () {
    test('juros total somado em CADA parcela', () {
      final s = LoanCalculator.installmentSchedule(
        capital: 1000,
        ratePercent: 20,
        count: 4,
        startDate: DateTime(2025, 1, 15),
      );
      expect(s.length, 4);
      // juros = 200; parte capital = 250; parcela = 250 + 200 = 450
      expect(s.first.amount, 450.0);
      // total = 450 * 4 = 1800
      expect(LoanCalculator.scheduleTotal(s), closeTo(1800, 0.001));
      // vencimentos mensais
      expect(s[0].dueDate, DateTime(2025, 2, 15));
      expect(s[3].dueDate, DateTime(2025, 5, 15));
    });

    test('exemplo da especificação: 1000, 10%, 4 parcelas = 350 cada', () {
      final s = LoanCalculator.installmentSchedule(
        capital: 1000,
        ratePercent: 10,
        count: 4,
        startDate: DateTime(2025, 1, 15),
      );
      expect(s.first.amount, 350.0);
      expect(LoanCalculator.scheduleTotal(s), closeTo(1400, 0.001));
    });

    test('última parcela absorve arredondamento do capital', () {
      final s = LoanCalculator.installmentSchedule(
        capital: 1000,
        ratePercent: 10,
        count: 3,
        startDate: DateTime(2025, 1, 31),
      );
      // juros = 100 em cada; total = 1000 + 100*3 = 1300
      final total = LoanCalculator.scheduleTotal(s);
      expect(total, closeTo(1300, 0.001));
      // fevereiro não tem dia 31 -> ajusta para 28
      expect(s[0].dueDate, DateTime(2025, 2, 28));
    });
  });
}
