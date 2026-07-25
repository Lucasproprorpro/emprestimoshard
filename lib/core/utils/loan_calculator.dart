import '../constants/enums.dart';
import '../../data/models/installment.dart';
import 'date_utils.dart';

/// Regras de cálculo das três modalidades de empréstimo.
///
/// Todas as funções são PURAS (sem efeitos colaterais) para facilitar testes.
/// As premissas de cada modalidade estão documentadas abaixo e podem ser
/// ajustadas em um único lugar sem afetar o restante do app.
class LoanCalculator {
  /// Arredonda para 2 casas decimais.
  static double round2(double v) => (v * 100).roundToDouble() / 100;

  // -------------------------------------------------------------- PENHOR

  /// Penhor: o cliente paga apenas os juros sobre o capital.
  /// Ex.: capital 1000, taxa 10%  ->  juros 100 por período.
  static double pledgeInterest(double capital, double ratePercent) =>
      round2(capital * ratePercent / 100);

  // -------------------------------------------------------------- DIÁRIO

  /// Diário: gera uma agenda com [termDays] dias.
  ///
  /// Premissa: a taxa informada é o percentual DIÁRIO sobre o capital.
  /// valor por dia = capital * taxa/100  (mesmo valor todos os dias)
  /// total a receber = valor por dia * termDays
  /// Ex.: capital 1000, taxa 6%, 20 dias -> R$60/dia, total R$1200.
  /// O primeiro vencimento é no dia seguinte ao [startDate].
  static double dailyAmount(double capital, double ratePercent) =>
      round2(capital * ratePercent / 100);

  static List<LoanInstallment> dailySchedule({
    required double capital,
    required double ratePercent,
    required int termDays,
    required DateTime startDate,
  }) {
    assert(termDays > 0);
    final perDay = dailyAmount(capital, ratePercent);
    final start = DateOnly.of(startDate);

    final items = <LoanInstallment>[];
    for (int day = 1; day <= termDays; day++) {
      items.add(LoanInstallment(
        number: day,
        dueDate: start.add(Duration(days: day)),
        amount: perDay,
        status: PaymentStatus.future,
      ));
    }
    return items;
  }

  // ------------------------------------------------------------ PARCELADO

  /// Parcelado: divide o capital pelo número de parcelas e soma o JUROS TOTAL
  /// em CADA parcela.
  ///
  /// juros total   = capital * taxa/100        (mesmo valor em toda parcela)
  /// parte capital = capital / n               (última ajusta o arredondamento)
  /// parcela       = parte capital + juros total
  /// total         = capital + (juros total * n)
  /// Ex.: capital 1000, taxa 10%, 4 parcelas -> (250 + 100) = R$350/parcela,
  /// total R$1400.
  /// Vencimentos mensais a partir de um mês após o [startDate].
  static List<LoanInstallment> installmentSchedule({
    required double capital,
    required double ratePercent,
    required int count,
    required DateTime startDate,
  }) {
    assert(count > 0);
    final interest = round2(capital * ratePercent / 100);
    final capitalBase = round2(capital / count);
    final start = DateOnly.of(startDate);

    final items = <LoanInstallment>[];
    double accumulatedCapital = 0;
    for (int i = 1; i <= count; i++) {
      final isLast = i == count;
      final capitalPart =
          isLast ? round2(capital - accumulatedCapital) : capitalBase;
      accumulatedCapital = round2(accumulatedCapital + capitalPart);
      items.add(LoanInstallment(
        number: i,
        dueDate: DateOnly.addMonths(start, i),
        amount: round2(capitalPart + interest),
        status: PaymentStatus.future,
      ));
    }
    return items;
  }

  // ------------------------------------------------------------- helpers

  /// Total a receber de uma agenda gerada.
  static double scheduleTotal(List<LoanInstallment> schedule) =>
      round2(schedule.fold(0.0, (s, i) => s + i.amount));

  /// Juros embutidos na agenda (total - capital).
  static double scheduleInterest(
          List<LoanInstallment> schedule, double capital) =>
      round2(scheduleTotal(schedule) - capital);
}
