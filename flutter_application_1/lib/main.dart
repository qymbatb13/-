import 'package:flutter/material.dart';

// ---------- Модели и «база данных» в памяти ----------
enum Role { student, employer }
enum TaskStatus { active, assigned, paid }
enum ReplyStatus { pending, accepted, rejected }

const categories = ['Промоутер', 'Репетиторство', 'Доставка', 'Склад', 'Мероприятия', 'Дизайн', 'IT', 'Другое'];
const commission = 0.10;

String money(int n) => '${n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ')} ₸';

class AppUser {
  AppUser(this.name, this.age, this.role);
  final String name;
  final int age;
  final Role role;
  int balance = 0, done = 0;
  final List<int> ratings = [];
  double get rating => ratings.isEmpty ? 0 : ratings.reduce((a, b) => a + b) / ratings.length;
}

class Task {
  Task({required this.title, required this.description, required this.category, required this.place,
      required this.online, required this.date, required this.time, required this.pay,
      required this.people, required this.minAge, required this.employer});
  final String title, description, category, place, date, time;
  final bool online;
  final int pay, people, minAge;
  final AppUser employer;
  TaskStatus status = TaskStatus.active;
  String get statusText => const {
        TaskStatus.active: 'Активно',
        TaskStatus.assigned: 'Исполнитель выбран',
        TaskStatus.paid: 'Оплачено',
      }[status]!;
}

class Reply {
  Reply(this.task, this.student, this.message);
  final Task task;
  final AppUser student;
  final String message;
  ReplyStatus status = ReplyStatus.pending;
  String get statusText => const {
        ReplyStatus.pending: 'Ожидает ответа',
        ReplyStatus.accepted: 'Принят',
        ReplyStatus.rejected: 'Отклонён',
      }[status]!;
}

class Store extends ChangeNotifier {
  final users = <AppUser>[];
  final tasks = <Task>[];
  final replies = <Reply>[];
  AppUser? me;

  Store() {
    final mart = AppUser('Mart ТРЦ', 30, Role.employer);
    users.add(mart);
    Task t(String title, String desc, String cat, String place, bool online, String date, String time,
            int pay, int people, int minAge) =>
        Task(title: title, description: desc, category: cat, place: place, online: online, date: date,
            time: time, pay: pay, people: people, minAge: minAge, employer: mart);
    tasks.addAll([
      t('Промоутер на выходные', 'Раздача листовок возле ТРЦ. Опыт не нужен, листовки и инструкцию выдаём.',
          'Промоутер', 'Тараз, ТРЦ Mart', false, '10 октября', '12:00–16:00', 5000, 3, 16),
      t('Помощь на складе', 'Разгрузка и сортировка товара. Перчатки выдаём.', 'Склад', 'Тараз, ул. Сулейменова 12',
          false, '11 октября', '09:00–15:00', 7000, 2, 18),
      t('Математика для 7 класса', 'Помощь с домашним заданием и подготовкой к контрольной.', 'Репетиторство',
          'Онлайн', true, '12 октября', '16:00–18:00', 4000, 1, 16),
      t('Дизайн афиши в Canva', 'Афиша для школьного мероприятия, формат A3.', 'Дизайн', 'Онлайн', true,
          '13 октября', 'В течение дня', 8000, 1, 16),
    ]);
  }

  void login(String name, int age, Role role) {
    me = users.firstWhere((u) => u.name == name && u.role == role, orElse: () {
      final u = AppUser(name, age, role);
      users.add(u);
      return u;
    });
    notifyListeners();
  }

  void logout() {
    me = null;
    notifyListeners();
  }

  void addTask(Task t) {
    tasks.insert(0, t);
    notifyListeners();
  }

  void apply(Task t, String msg) {
    replies.add(Reply(t, me!, msg));
    notifyListeners();
  }

  Reply? replyOf(Task t) => replies.where((r) => r.task == t && r.student == me).firstOrNull;
  List<Reply> repliesFor(Task t) => replies.where((r) => r.task == t).toList();
  int acceptedCount(Task t) => replies.where((r) => r.task == t && r.status == ReplyStatus.accepted).length;

  void decide(Reply r, bool ok) {
    r.status = ok ? ReplyStatus.accepted : ReplyStatus.rejected;
    if (ok) r.task.status = TaskStatus.assigned;
    notifyListeners();
  }

  /// Подтверждение работы: деньги проходят через платформу, 10% — комиссия.
  void payOut(Task t, int stars) {
    for (final r in repliesFor(t).where((r) => r.status == ReplyStatus.accepted)) {
      r.student.balance += (t.pay * (1 - commission)).round();
      r.student.done++;
      r.student.ratings.add(stars);
    }
    t.status = TaskStatus.paid;
    notifyListeners();
  }
}

final store = Store();

Widget watch(Widget Function() build) => ListenableBuilder(listenable: store, builder: (_, __) => build());

Widget info(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [Icon(icon, size: 16), const SizedBox(width: 6), Flexible(child: Text(text))]),
    );

// ---------- Приложение ----------
void main() => runApp(const QuickJobApp());

class QuickJobApp extends StatelessWidget {
  const QuickJobApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'QuickJob',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF0F766E)),
        home: watch(() => store.me == null ? const LoginPage() : const HomePage()),
      );
}

// ---------- Вход ----------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final name = TextEditingController();
  final age = TextEditingController(text: '17');
  Role role = Role.student;
  String? error;

  void go() {
    final n = name.text.trim();
    final a = int.tryParse(age.text) ?? 0;
    if (n.isEmpty) return setState(() => error = 'Введите имя');
    if (a < 16) return setState(() => error = 'Сервис доступен с 16 лет');
    store.login(n, a, role);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            const SizedBox(height: 32),
            Text('Найди подработку рядом с собой', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Короткие задания на несколько часов. ${store.tasks.length} доступно сегодня.'),
            const SizedBox(height: 24),
            SegmentedButton<Role>(
              segments: const [
                ButtonSegment(value: Role.student, label: Text('Ищу подработку')),
                ButtonSegment(value: Role.employer, label: Text('Размещаю задачи')),
              ],
              selected: {role},
              onSelectionChanged: (s) => setState(() => role = s.first),
            ),
            const SizedBox(height: 16),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Имя', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
                controller: age,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Возраст', border: OutlineInputBorder())),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 16),
            FilledButton(onPressed: go, child: const Text('Войти')),
            TextButton(
                onPressed: () {
                  name.text = 'Mart ТРЦ';
                  age.text = '30';
                  setState(() => role = Role.employer);
                },
                child: const Text('Демо: заполнить данные работодателя')),
          ]),
        ),
      );
}

// ---------- Главный экран ----------
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int i = 0;
  @override
  Widget build(BuildContext context) {
    final student = store.me!.role == Role.student;
    final tabs = student
        ? [const CatalogTab(), const MyRepliesTab(), const ProfileTab()]
        : [const MyTasksTab(), const ProfileTab()];
    final dests = student
        ? const [
            NavigationDestination(icon: Icon(Icons.search), label: 'Задания'),
            NavigationDestination(icon: Icon(Icons.send), label: 'Отклики'),
            NavigationDestination(icon: Icon(Icons.person), label: 'Профиль'),
          ]
        : const [
            NavigationDestination(icon: Icon(Icons.work), label: 'Мои задачи'),
            NavigationDestination(icon: Icon(Icons.person), label: 'Профиль'),
          ];
    if (i >= tabs.length) i = 0;
    return Scaffold(
      body: tabs[i],
      floatingActionButton: !student && i == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTaskPage())),
              icon: const Icon(Icons.add),
              label: const Text('Новая задача'))
          : null,
      bottomNavigationBar:
          NavigationBar(selectedIndex: i, destinations: dests, onDestinationSelected: (v) => setState(() => i = v)),
    );
  }
}

// ---------- Каталог ----------
class TaskCard extends StatelessWidget {
  const TaskCard(this.t, {super.key});
  final Task t;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: InkWell(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => store.me!.role == Role.student ? TaskPage(t) : EmployerTaskPage(t))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.title, style: Theme.of(context).textTheme.titleMedium),
              Text(t.category, style: Theme.of(context).textTheme.bodySmall),
              info(Icons.place, t.place),
              info(Icons.event, '${t.date}, ${t.time}'),
              info(Icons.group, 'Нужно: ${t.people} · ${t.minAge}+'),
              const SizedBox(height: 8),
              Text(money(t.pay), style: Theme.of(context).textTheme.titleLarge),
            ]),
          ),
        ),
      );
}

class CatalogTab extends StatefulWidget {
  const CatalogTab({super.key});
  @override
  State<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<CatalogTab> {
  String q = '', cat = 'Все';
  bool? online;

  @override
  Widget build(BuildContext context) => watch(() {
        final me = store.me!;
        final list = store.tasks
            .where((t) =>
                t.status == TaskStatus.active &&
                me.age >= t.minAge &&
                (cat == 'Все' || t.category == cat) &&
                (online == null || t.online == online) &&
                t.title.toLowerCase().contains(q.toLowerCase()))
            .toList();
        return SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                  onChanged: (v) => setState(() => q = v),
                  decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Сегодня доступно ${list.length} заданий',
                      border: const OutlineInputBorder())),
            ),
            SizedBox(
              height: 48,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
                for (final c in ['Все', ...categories])
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(label: Text(c), selected: cat == c, onSelected: (_) => setState(() => cat = c))),
              ]),
            ),
            Row(children: [
              const SizedBox(width: 16),
              FilterChip(label: const Text('Онлайн'), selected: online == true, onSelected: (s) => setState(() => online = s ? true : null)),
              const SizedBox(width: 8),
              FilterChip(label: const Text('Офлайн'), selected: online == false, onSelected: (s) => setState(() => online = s ? false : null)),
            ]),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('Заданий нет. Сбросьте фильтры или зайдите позже.'))
                  : ListView.builder(itemCount: list.length, itemBuilder: (_, k) => TaskCard(list[k])),
            ),
          ]),
        );
      });
}

// ---------- Страница задания (исполнитель) ----------
class TaskPage extends StatelessWidget {
  const TaskPage(this.t, {super.key});
  final Task t;

  Future<void> apply(BuildContext context) async {
    final c = TextEditingController(text: 'Здравствуйте! Я свободен в это время и хотел бы выполнить задачу.');
    final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
              title: const Text('Откликнуться'),
              content: TextField(controller: c, maxLines: 3),
              actions: [
                TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Отмена')),
                FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Отправить отклик')),
              ],
            ));
    if (ok == true) store.apply(t, c.text.trim());
  }

  @override
  Widget build(BuildContext context) => watch(() {
        final r = store.replyOf(t);
        return Scaffold(
          appBar: AppBar(title: Text(t.title)),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Text(money(t.pay), style: Theme.of(context).textTheme.headlineMedium),
            info(Icons.place, t.place),
            info(Icons.event, '${t.date}, ${t.time}'),
            info(Icons.group, 'Требуется: ${t.people} · возраст ${t.minAge}+'),
            info(Icons.business, 'Работодатель: ${t.employer.name}'),
            const SizedBox(height: 16),
            Text('Описание', style: Theme.of(context).textTheme.titleMedium),
            Text(t.description),
            const SizedBox(height: 24),
            if (r != null)
              Chip(label: Text('Ваш отклик: ${r.statusText}'))
            else if (t.status != TaskStatus.active)
              const Text('Набор закрыт')
            else
              FilledButton(onPressed: () => apply(context), child: const Text('Откликнуться')),
          ]),
        );
      });
}

class MyRepliesTab extends StatelessWidget {
  const MyRepliesTab({super.key});
  @override
  Widget build(BuildContext context) => watch(() {
        final mine = store.replies.where((r) => r.student == store.me).toList();
        return SafeArea(
          child: mine.isEmpty
              ? const Center(child: Text('Откликов пока нет. Выберите задание во вкладке «Задания».'))
              : ListView(children: [
                  for (final r in mine)
                    ListTile(
                      title: Text(r.task.title),
                      subtitle: Text('${r.task.date} · ${money(r.task.pay)}'),
                      trailing: Chip(label: Text(r.statusText)),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskPage(r.task))),
                    ),
                ]),
        );
      });
}

// ---------- Работодатель ----------
class MyTasksTab extends StatelessWidget {
  const MyTasksTab({super.key});
  @override
  Widget build(BuildContext context) => watch(() {
        final mine = store.tasks.where((t) => t.employer == store.me).toList();
        return SafeArea(
          child: mine.isEmpty
              ? const Center(child: Text('Задач нет. Нажмите «Новая задача».'))
              : ListView.builder(itemCount: mine.length, itemBuilder: (_, k) => TaskCard(mine[k])),
        );
      });
}

class EmployerTaskPage extends StatelessWidget {
  const EmployerTaskPage(this.t, {super.key});
  final Task t;

  Future<void> finish(BuildContext context) async {
    final stars = await showDialog<int>(
        context: context,
        builder: (d) => SimpleDialog(title: const Text('Оцените исполнителей'), children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var s = 1; s <= 5; s++) TextButton(onPressed: () => Navigator.pop(d, s), child: Text('$s ★')),
              ]),
            ]));
    if (stars != null) store.payOut(t, stars);
  }

  @override
  Widget build(BuildContext context) => watch(() {
        final rs = store.repliesFor(t);
        final accepted = store.acceptedCount(t);
        return Scaffold(
          appBar: AppBar(title: Text(t.title)),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Text('Статус: ${t.statusText}', style: Theme.of(context).textTheme.titleMedium),
            info(Icons.payments, '${money(t.pay)} на человека · комиссия ${(commission * 100).round()}%'),
            const SizedBox(height: 16),
            Text('Отклики (${rs.length})', style: Theme.of(context).textTheme.titleMedium),
            if (rs.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Откликов пока нет.')),
            for (final r in rs)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${r.student.name}, ${r.student.age} лет', style: Theme.of(context).textTheme.titleSmall),
                    Text('★ ${r.student.rating == 0 ? 'нет оценок' : r.student.rating.toStringAsFixed(1)} · выполнено: ${r.student.done}'),
                    const SizedBox(height: 4),
                    Text(r.message),
                    const SizedBox(height: 8),
                    if (r.status == ReplyStatus.pending && t.status != TaskStatus.paid)
                      Row(children: [
                        FilledButton(onPressed: accepted < t.people ? () => store.decide(r, true) : null, child: const Text('Принять')),
                        const SizedBox(width: 8),
                        OutlinedButton(onPressed: () => store.decide(r, false), child: const Text('Отклонить')),
                      ])
                    else
                      Chip(label: Text(r.statusText)),
                  ]),
                ),
              ),
            const SizedBox(height: 16),
            if (accepted > 0 && t.status == TaskStatus.assigned)
              FilledButton(onPressed: () => finish(context), child: Text('Подтвердить выполнение и оплатить ${money(t.pay * accepted)}')),
          ]),
        );
      });
}

class CreateTaskPage extends StatefulWidget {
  const CreateTaskPage({super.key});
  @override
  State<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends State<CreateTaskPage> {
  final title = TextEditingController(), desc = TextEditingController(), place = TextEditingController(),
      date = TextEditingController(), time = TextEditingController(), pay = TextEditingController(),
      people = TextEditingController(text: '1');
  String cat = categories.first;
  bool online = false;
  int minAge = 16;
  String? error;

  Widget field(TextEditingController c, String label, {bool number = false, int lines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
            controller: c,
            maxLines: lines,
            keyboardType: number ? TextInputType.number : null,
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
      );

  void save() {
    final p = int.tryParse(pay.text) ?? 0, n = int.tryParse(people.text) ?? 0;
    if ([title, desc, date, time].any((c) => c.text.trim().isEmpty) || (!online && place.text.trim().isEmpty) || p <= 0 || n <= 0) {
      return setState(() => error = 'Заполните все поля, оплата и число людей должны быть больше нуля');
    }
    store.addTask(Task(
        title: title.text.trim(), description: desc.text.trim(), category: cat,
        place: online ? 'Онлайн' : place.text.trim(), online: online, date: date.text.trim(),
        time: time.text.trim(), pay: p, people: n, minAge: minAge, employer: store.me!));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Новая задача')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          field(title, 'Название'),
          field(desc, 'Описание', lines: 3),
          DropdownButtonFormField<String>(
              value: cat,
              decoration: const InputDecoration(labelText: 'Категория', border: OutlineInputBorder()),
              items: [for (final c in categories) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => cat = v!)),
          SwitchListTile(title: const Text('Онлайн'), value: online, onChanged: (v) => setState(() => online = v)),
          if (!online) field(place, 'Место'),
          field(date, 'Дата, например 10 октября'),
          field(time, 'Время, например 12:00–16:00'),
          field(pay, 'Оплата на человека, ₸', number: true),
          field(people, 'Сколько человек нужно', number: true),
          SegmentedButton<int>(
              segments: const [ButtonSegment(value: 16, label: Text('С 16 лет')), ButtonSegment(value: 18, label: Text('С 18 лет'))],
              selected: {minAge},
              onSelectionChanged: (s) => setState(() => minAge = s.first)),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 16),
          FilledButton(onPressed: save, child: const Text('Опубликовать')),
        ]),
      );
}

// ---------- Профиль ----------
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});
  @override
  Widget build(BuildContext context) => watch(() {
        final me = store.me!;
        final student = me.role == Role.student;
        return SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text(me.name, style: Theme.of(context).textTheme.headlineMedium),
            Text(student ? 'Исполнитель, ${me.age} лет' : 'Работодатель'),
            const SizedBox(height: 16),
            if (student) ...[
              info(Icons.star, me.ratings.isEmpty ? 'Рейтинг: пока нет оценок' : 'Рейтинг: ${me.rating.toStringAsFixed(1)} / 5'),
              info(Icons.check_circle, 'Выполнено задач: ${me.done}'),
              info(Icons.account_balance_wallet, 'Баланс: ${money(me.balance)}'),
            ] else
              info(Icons.work, 'Задач опубликовано: ${store.tasks.where((t) => t.employer == me).length}'),
            const SizedBox(height: 24),
            OutlinedButton(onPressed: store.logout, child: const Text('Выйти')),
          ]),
        );
      });
}