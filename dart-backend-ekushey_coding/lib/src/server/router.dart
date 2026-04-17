import 'package:shelf_router/shelf_router.dart';

import 'context.dart';
import 'routes/admin_blog_routes.dart';
import 'routes/admin_exercise_routes.dart';
import 'routes/admin_tutorial_routes.dart';
import 'routes/auth_routes.dart';
import 'routes/blog_routes.dart';
import 'routes/exercise_routes.dart';
import 'routes/profile_routes.dart';
import 'routes/tutorial_routes.dart';

Router buildApiRouter(ApiContext api) {
  final router = Router();

  registerAuthRoutes(router, api);
  registerProfileRoutes(router, api);
  registerBlogRoutes(router, api);
  registerTutorialRoutes(router, api);
  registerExerciseRoutes(router, api);

  registerAdminBlogRoutes(router, api);
  registerAdminExerciseRoutes(router, api);
  registerAdminTutorialRoutes(router, api);

  return router;
}
