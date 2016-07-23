var gulp = require('gulp');
var coffee = require('gulp-coffeeify');

gulp.task('default', ['scripts', 'watch']);

gulp.task('scripts', function() {
  gulp.src('./src/*.coffee')
  .pipe(coffee())
  .pipe(gulp.dest('./dest/'));
});

gulp.task('watch', function () {
  gulp.watch('./src/*.coffee', ['scripts']);
  gulp.watch('./src/style.scss', ['sass']);
});
