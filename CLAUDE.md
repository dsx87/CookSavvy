## About project
- This is hobby iOS app. Written in Swift. Using SwiftUI for UI, UIKit only if there is no other option. And project intended to use maximum of apple frameworks
- This app is about to give user food recipes from ingredients user entered
- the app should contain these screens: ingredinet entering screen (initial), search results(shows the search result of the ingredients input), recipe screen (all recipe details), recent recipes, favorites recipes, settings
- the app will be have three subscribtion models: free, api (some api with curated recipeps) and AI generated.
- the app will use camera to make picture of ingredients and AI to detect ingredients on the photo (only on subscription)

## subscription models description:
- free: should use local database
- api: will use REST api of some service and AI model to detect ingredients on photo
- AI: will use some AI model to provide recipes and detect ingredients on photo

## Screens Description:
- Ingredients entering screen: has to offer text input, camera input (photo with ai recognition), recent ingredients. during text input the autocompletion popup should appear
- search results: shows finded recipes in table. each row contains, name, pic, complexity, time to cook
- recent recipes: same as search results, but showing recently selected recipes
- favorires: same as search results, shows recipes marked with favorite flag
- recipe screen: screen filled with details of the recipe
- settings: shows subscription plan, limits, etc
- every secreen intented to be extended and maybe changed

## General Rules:
- The app has to follow MVVM pattern. View should not contain any properties except viewModel. every variable should be stored inside viewmodel
- the app should be strictly structurized: create services as needed, keep single responsibility principe
- When adding new code - always keep app structure and best practices 
- code duplication is not allowed. Search for existing solution and use it. Refactor existing code if needed, but only if needed! Think before refactor: maybe you can reuse existing functionality without refactor or you can add new method instead modyfing exising one. Duplication can be made but only id really needed: like unrelated modules or logic that looks identincal but can evolve in something different. and only with my approval
- if you need additional info for best answer - ask, do not write code until you have all info, or i explicitly instruct you to write without claryfication
- sometimes comments are needed. i will instruct you with comments details. possible comments level: none, needed only, every line. default - none
