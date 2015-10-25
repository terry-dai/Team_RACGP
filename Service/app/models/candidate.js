var mongoose     = require('mongoose');
var Schema       = mongoose.Schema;

var CandidateSchema   = new Schema({
	FName: String,
	Sname: String,
	Venue: String
});

module.exports = mongoose.model('Candidate', CandidateSchema);