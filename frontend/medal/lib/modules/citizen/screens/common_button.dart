import 'package:flutter/material.dart';
import 'package:medal/modules/citizen/screens/components.dart';


Widget commonBottomNav(
  BuildContext context,
  int currentIndex,
) {
  return BottomNavigationBar(
    currentIndex: currentIndex,

    type: BottomNavigationBarType.fixed,

    selectedItemColor:
        const Color(0xFF0467B6),

    onTap: (index) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => MainScreen(
            initialIndex: index,
          ),
        ),
        (route) => false,
      );
    },

    items: const [

      BottomNavigationBarItem(
        icon: Icon(Icons.feed_outlined),
        label: "Feed",
      ),

      BottomNavigationBarItem(
        icon: Icon(Icons.track_changes),
        label: "Tracker",
      ),

      BottomNavigationBarItem(
        icon: Icon(
          Icons.add_circle,
          size: 35,
        ),
        label: "Report",
      ),

      BottomNavigationBarItem(
        icon: Icon(Icons.school),
        label: "Academy",
      ),

      BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: "Profile",
      ),
    ],
  );
}