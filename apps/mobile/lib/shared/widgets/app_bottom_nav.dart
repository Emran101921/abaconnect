import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';

enum ParentNavTab { home, children, screening, messages }

enum TherapistNavTab { home, appointments, sessions, messages }

class ParentBottomNav extends StatelessWidget {
  const ParentBottomNav({super.key, required this.current});

  final ParentNavTab current;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: current.index,
      onDestinationSelected: (index) {
        final tab = ParentNavTab.values[index];
        if (tab == current) return;
        switch (tab) {
          case ParentNavTab.home:
            context.go(AppRoutes.parentHome);
          case ParentNavTab.children:
            context.go(AppRoutes.parentChildren);
          case ParentNavTab.screening:
            context.go(AppRoutes.parentScreening);
          case ParentNavTab.messages:
            context.go(AppRoutes.messages);
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.child_care_outlined),
          selectedIcon: Icon(Icons.child_care),
          label: 'Children',
        ),
        NavigationDestination(
          icon: Icon(Icons.assignment_outlined),
          selectedIcon: Icon(Icons.assignment),
          label: 'Screening',
        ),
        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline),
          selectedIcon: Icon(Icons.chat_bubble),
          label: 'Messages',
        ),
      ],
    );
  }
}

class TherapistBottomNav extends StatelessWidget {
  const TherapistBottomNav({super.key, required this.current});

  final TherapistNavTab current;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: current.index,
      onDestinationSelected: (index) {
        final tab = TherapistNavTab.values[index];
        if (tab == current) return;
        switch (tab) {
          case TherapistNavTab.home:
            context.go(AppRoutes.therapistHome);
          case TherapistNavTab.appointments:
            context.go(AppRoutes.therapistAppointments);
          case TherapistNavTab.sessions:
            context.go(AppRoutes.therapistSessionNotes);
          case TherapistNavTab.messages:
            context.go(AppRoutes.messages);
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.event_outlined),
          selectedIcon: Icon(Icons.event),
          label: 'Schedule',
        ),
        NavigationDestination(
          icon: Icon(Icons.note_alt_outlined),
          selectedIcon: Icon(Icons.note_alt),
          label: 'Sessions',
        ),
        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline),
          selectedIcon: Icon(Icons.chat_bubble),
          label: 'Messages',
        ),
      ],
    );
  }
}
