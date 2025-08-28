const path = require('path');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');

module.exports = {
  entry: {
    app: ['./js/app.js', './css/app.css']
  },
  output: {
    filename: 'assets/app.js',
    path: path.resolve(__dirname, '../priv/static'),
    publicPath: '/'
  },
  module: {
    rules: [
      {
        test: /\.css$/i,
        use: [
          MiniCssExtractPlugin.loader,
          'css-loader' // Only using css-loader, no PostCSS for now
        ]
      },
      {
        test: /\.(woff|woff2|eot|ttf|svg)$/i,
        type: 'asset/resource',
        generator: {
          filename: 'assets/fonts/[name][ext]',
        },
      },
    ]
  },
  plugins: [
    new MiniCssExtractPlugin({
      filename: 'assets/app.css'
    })
  ]
};
