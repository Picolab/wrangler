// Require chai.js expect module for assertions
var assert = require('chai').assert, 
	should = require('chai').should(),
    supertest = require('supertest'),
    event_api = supertest("https://kibdev.kobj.net/sky/event/D7898552-0AFC-11E6-A7BC-38D4E71C24E1");
    sky_query = supertest("https://kibdev.kobj.net/sky/cloud/b507199x5.dev");

describe('children(_eci)', function() {

  it('array of child tuples errors if not 200', function(done) {
    event_api.get('/children')
    .set('Accept', 'application/json')
    .query({ _eci: 'D7898552-0AFC-11E6-A7BC-38D4E71C24E1' })
    .expect(200, done)
    .expect('Content-Type', /json/)
  });

});

describe('createChild(TestDriver)', function() {

  it('errors if not 200', function(done) {
    event_api.get('/123/wrangler/child_creation')
    .set('Accept', 'application/json')
    .query({ name: 'TestDriver' })
    .expect(200, done)
    .expect('Content-Type', /json/)
  });

});
