/**
 * Search Page Object
 * =========================
 */

'use strict';

require('./waitReady.js');
var wait_times = require('./wait_times');

var Search = function() {
	this.searchForm = element(by.css('#search'));
	this.textInput = element(by.css('#quicksearch'));
	this.searchButton = this.searchForm.element(by.css('button.btn.btn-primary'));
	this.storyTellerTab = element(by.partialLinkText('Search for Storytellers'));
	this.resultsContainer = element(by.css('.clearfix.user.search-results'));
	this.searchResults = element.all(by.repeater('item in results | filter:itemFilter'));

	this.searchFor = function(searchString) {
		expect(this.searchButton.waitReady()).toBeTruthy();

		// Send the search text
		this.textInput.sendKeys(searchString);

		this.searchButton.click();
		browser.sleep(wait_times['search']);

		// Expect the url to change to search api
		browser.getCurrentUrl().then(function(newURL){
			expect(newURL.indexOf('/search/') >= 0 ).toBeTruthy();
		});
	};
};

module.exports = new Search();
