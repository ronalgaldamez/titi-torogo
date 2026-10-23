<?php

namespace Tests\Feature;

use Tests\TestCase;
use Illuminate\Foundation\Testing\DatabaseMigrations;

class ExampleTest extends TestCase
{
    use DatabaseMigrations;

    public function test_home_shows_the_public_landing(): void
    {
        $response = $this->get('/');

        $response->assertOk()->assertSee('Lo bueno');
    }
}
