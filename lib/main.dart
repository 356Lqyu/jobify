import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AnimatedHomePage(),
    );
  }
}

class AnimatedHomePage extends StatefulWidget {
  const AnimatedHomePage({super.key});

  @override
  State<AnimatedHomePage> createState() => _AnimatedHomePageState();
}

class _AnimatedHomePageState extends State<AnimatedHomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),

    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              /// Logo
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 330,
                  height: 200,
                  child: Image.asset(
                    'assets/images/logo3.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              /// Title
              Text(
                'Welcome to Jobify',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),

              /// Subtitle
              Text(
                'Find jobs or hire talent easily',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.blueGrey),
              ),

              const SizedBox(height: 40),

              /// Job Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 8,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {},
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.work, color: Colors.white, size: 25),
                      SizedBox(width: 10),
                      Text("I'm Looking for a job.", style: TextStyle(fontSize: 17)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 15),

              /// Hiring Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 8,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: const BorderSide(color: Colors.blue),
                    ),
                  ),
                  onPressed: () {},
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.group_add, color: Colors.white, size: 25),
                      SizedBox(width: 10),
                      Text("I'm Hiring.", style: TextStyle(fontSize: 17)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 25),

              /// Login Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account?',
                    style: TextStyle(fontSize: 15, color: Colors.blueGrey),
                  ),
                  TextButton(
                    onPressed: () {
                      /*Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => LoginPage()),
                            ); */
                    },
                    child: Text(
                      'Log in',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
