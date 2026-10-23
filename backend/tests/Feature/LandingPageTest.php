<?php

namespace Tests\Feature;

use App\Models\LandingPage;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class LandingPageTest extends TestCase
{
    use DatabaseMigrations;

    private function data(): array
    {
        return ['content' => LandingPage::defaults()];
    }

    private function image(string $name = 'portada.png'): UploadedFile
    {
        return UploadedFile::fake()->createWithContent($name, base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j1ioAAAAASUVORK5CYII='));
    }

    public function test_public_page_has_defaults_working_links_and_does_not_create_settings_on_read(): void
    {
        $this->get('/')->assertOk()->assertSee('Lo bueno')->assertSee('Sabores de')
            ->assertSee(route('web.order'), false)->assertSee('images/landing/pupusas.webp', false)
            ->assertDontSee('data:image/', false)->assertDontSee('ORDER_EXPERIENCE', false)
            ->assertSee('De nuestra gente.')->assertSee('Para tus antojos.')
            ->assertSee('Google Play')->assertSee('App Store')->assertSee('AppGallery')
            ->assertSee('Descargas aún no disponibles.')->assertDontSee('SABOR LOCAL')
            ->assertSee('images/landing/pupusas-banner.webp', false)
            ->assertSee('Preferencias de cookies')->assertSee('Términos y condiciones')
            ->assertSee('La política de privacidad aún no está publicada.')
            ->assertSee('no permite cambiar preferencias ni registra consentimiento.');
        $this->get('/pedir')->assertOk()->assertSee('no permite crear pedidos');
        $this->assertDatabaseCount('landing_pages', 0);
        $this->get('/web/imagenes/hero')->assertNotFound();
        $this->get('/web/imagenes/invalid')->assertNotFound();
    }

    public function test_only_admin_can_read_and_publish_the_landing_editor(): void
    {
        $this->withoutVite();
        $this->get('/admin/pagina-web')->assertRedirect('/admin/login');
        $this->put('/admin/pagina-web', $this->data())->assertRedirect('/admin/login');
        foreach (['client', 'restaurant', 'courier'] as $role) {
            $user = $role === 'client' ? User::factory()->create() : User::factory()->{$role}()->create();
            $this->actingAs($user);
            $this->get('/admin/pagina-web')->assertForbidden();
            $this->put('/admin/pagina-web', $this->data())->assertForbidden();
        }
        $this->assertDatabaseCount('landing_pages', 0);
        $this->actingAs(User::factory()->admin()->create());
        $this->get('/admin/pagina-web')->assertOk()->assertSee('Guardar y publicar');
    }

    public function test_admin_edits_persist_and_public_output_escapes_html(): void
    {
        $this->actingAs(User::factory()->admin()->create());
        $data = $this->data();
        $data['content']['hero_title'] = "De aquí\npara vos";
        $data['content']['story_intro'] = '<script>alert("test")</script>';
        $data['content']['contact_email'] = 'equipo@example.com';
        $this->put('/admin/pagina-web', $data)->assertSessionHasNoErrors()->assertRedirect('/admin/pagina-web');
        $this->assertSame("De aquí\npara vos", LandingPage::current()->content['hero_title']);
        $this->get('/')->assertOk()->assertSee('De aquí')->assertSee(e($data['content']['story_intro']), false)
            ->assertDontSee($data['content']['story_intro'], false)->assertSee('mailto:equipo@example.com', false);
        $this->put('/admin/pagina-web', $data)->assertSessionHasNoErrors();
        $this->assertDatabaseCount('landing_pages', 1);
    }

    public function test_invalid_content_and_unsafe_uploads_leave_existing_page_unchanged(): void
    {
        Storage::fake('public');
        $this->actingAs(User::factory()->admin()->create());
        $this->put('/admin/pagina-web', $this->data())->assertSessionHasNoErrors();
        $original = LandingPage::current()->content;
        foreach (['', str_repeat('x', 1201), ['unexpected']] as $title) {
            $data = $this->data();
            $data['content']['hero_title'] = $title;
            $this->put('/admin/pagina-web', $data)->assertSessionHasErrors('content.hero_title');
        }
        $data = $this->data();
        $data['content']['unknown'] = 'unexpected';
        $this->put('/admin/pagina-web', $data)->assertSessionHasErrors('content');
        $data = $this->data();
        $data['content']['contact_email'] = 'javascript:alert(1)';
        $this->put('/admin/pagina-web', $data)->assertSessionHasErrors('content.contact_email');
        $this->put('/admin/pagina-web', $this->data() + ['images' => ['hero' => UploadedFile::fake()->createWithContent('icon.svg', '<svg xmlns="http://www.w3.org/2000/svg"></svg>')]])
            ->assertSessionHasErrors('images.hero');
        $this->put('/admin/pagina-web', $this->data() + ['images' => ['hero' => UploadedFile::fake()->create('large.jpg', 4000, 'image/jpeg')]])
            ->assertSessionHasErrors('images.hero');
        $this->assertSame($original, LandingPage::current()->content);
        $this->assertSame([], Storage::disk('public')->allFiles());
    }

    public function test_images_can_be_uploaded_preserved_replaced_and_reset_independently(): void
    {
        Storage::fake('public');
        $this->actingAs(User::factory()->admin()->create());
        $this->put('/admin/pagina-web', $this->data() + ['images' => ['hero' => $this->image(), 'local' => $this->image('local.png')]])
            ->assertSessionHasNoErrors();
        $images = LandingPage::current()->images;
        Storage::disk('public')->assertExists($images['hero']);
        Storage::disk('public')->assertExists($images['local']);
        $this->get('/web/imagenes/hero')->assertOk()->assertHeader('Content-Type', 'image/png')->assertHeader('X-Content-Type-Options', 'nosniff');
        $this->put('/admin/pagina-web', $this->data())->assertSessionHasNoErrors();
        $this->assertSame($images, LandingPage::current()->images);
        $this->put('/admin/pagina-web', $this->data() + ['images' => ['hero' => $this->image('otra.png')]])->assertSessionHasNoErrors();
        $new = LandingPage::current()->images;
        $this->assertNotSame($images['hero'], $new['hero']);
        $this->assertSame($images['local'], $new['local']);
        Storage::disk('public')->assertMissing($images['hero']);
        Storage::disk('public')->assertExists($new['hero']);
        $this->put('/admin/pagina-web', $this->data() + ['remove_images' => ['hero' => true]])->assertSessionHasNoErrors();
        $this->assertNull(LandingPage::current()->images['hero']);
        Storage::disk('public')->assertMissing($new['hero']);
        Storage::disk('public')->assertExists($images['local']);
        $this->get('/')->assertOk()->assertSee('images/landing/pupusas.webp', false);
    }

    public function test_story_image_is_independent_and_can_be_reset_without_changing_hero(): void
    {
        Storage::fake('public');
        $this->actingAs(User::factory()->admin()->create());
        $this->put('/admin/pagina-web', $this->data() + ['images' => [
            'hero' => $this->image('hero.png'), 'story' => $this->image('story.png'),
        ]])->assertSessionHasNoErrors();
        $images = LandingPage::current()->images;
        $this->get('/web/imagenes/story')->assertOk()->assertHeader('Content-Type', 'image/png');
        $this->put('/admin/pagina-web', $this->data() + ['remove_images' => ['story' => true]])
            ->assertSessionHasNoErrors();
        $this->assertSame($images['hero'], LandingPage::current()->images['hero']);
        Storage::disk('public')->assertExists($images['hero']);
        Storage::disk('public')->assertMissing($images['story']);
        $this->get('/')->assertOk()->assertSee('images/landing/cocina-local.webp', false);
    }
}
