//
//  ViewController.m
//  SilverViewer
//
//  Created by 黄奕涵 on 2020/8/30.
//  Copyright © 2020 Bunny Wong. All rights reserved.
//

#import "ViewController.h"

typedef NS_ENUM(int16_t, image_format) {
  grayscale_4 = 0x0004, // 4  BPP                             Grayscale, 2 pixels per byte, first pixel in upper nibble
  grayscale_8 = 0x0008, // 8  BPP                             Grayscale
  rgb_16      = 0x0565, // 16 BPP (RGB565)                    Byte2:Byte1 = RRRRRGGG:GGGBBBBB
  argb_32     = 0x1888, // 32 BPP (ARGB8888)                  Byte4:Byte3:Byte2:Byte1 = A:R:G:B
  paletted_8  = 0x0064, // 8  BPP Paletted (256 colors max)   One int32 for palette size,
                        //                                      then 4 times that amount of ARGB8888 bytes,
                        //                                      then 8 BPP image data
  paletted_16 = 0x0065  // 16 BPP Paletted (65536 colors max) One int32 for palette size,
                        //                                      then 4 times that amount of ARGB8888 bytes,
                        //                                      then 16 BPP image data (LSB first)
};

typedef struct {
  int32_t magic;               // Magic? Format?       always 3h
  int32_t character_code_page; // Character code page? Differs only for Russian language and image packs
  int32_t table_type;          // DB Table type?       1h for iamge pack, 2h for language pack
  char    table_type_chr[4];   // DB Table type?       "paMB" for image pack, "mTDL" for language pack
  int32_t num_of_files;        // numFiles             Number of files in this pack
  int32_t flag_1;              // Unknown              always 1h
  int32_t flag_2;              // Unknown              1Ch for image pack, 2Ch for language pack
} silver_header;

typedef struct {
  int32_t serial_num; // File serial number
  int32_t offset;     // File offset starts counting at the address after this table,
                      //   so add 28 + 12 * numFiles to this number for file offset.
  int32_t size;       // File size
} file_entry;

typedef struct {
  int16_t image_format; // Format          See next table*
  int16_t flag_1;       // Unknown         always 1h
  int16_t sprite_width; // Width of sprite pixels
  int16_t flag_2;       // Flags?          I've only seen instances with just 1 bit set
  int32_t flag_3;       // Unused?
  int32_t flag_4;       // Unused?
  int32_t height;       // Height of frame pixels
  int32_t width;        // Width of frame  pixels
  int32_t serial;       // Serial          Same as serial in file table
  int32_t size;         // Size            Same as size in file table
} image_header;

// Note that an image describes a frame size and a (possibly smaller) sprite size.
// Only the sprite contains data and what happens to the letterboxing is unknown
//  (maybe one of the unknown fields defines it? Where I stumbled upon letterboxing,
//   it was supposed to be black)

@interface ViewController ()

@property (weak) IBOutlet NSImageView *imageView;

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  [self readSivler];
}

- (void)readSivler {
  NSData *silverData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SilverImagesDB.LE" ofType:@"bin"]];
  NSLog(@"%ld", [silverData length]);

  const void *raw_data = silverData.bytes;

  silver_header header;
  memcpy(&header, raw_data, sizeof(silver_header));

  int num_of_files = header.num_of_files;
  NSLog(@"Number of files: %d", num_of_files);

  file_entry enteries[num_of_files];

  const file_entry *entry_ptr = raw_data + sizeof(silver_header);
  memcpy(&enteries[0], entry_ptr, num_of_files * sizeof(file_entry));

  const image_header *image_ptr = raw_data + sizeof(silver_header) + num_of_files * sizeof(file_entry);
  for (int i = 0; i < num_of_files; i++) {
    file_entry cur_entry = enteries[i];
    NSLog(@"Idx: %4d, serial: %08x, offset: %d, size: %d", i, cur_entry.serial_num, cur_entry.offset, cur_entry.size);

    if (cur_entry.size == 0) {
      continue;
    }

    image_header *cur_image_ptr = (void *)image_ptr + cur_entry.offset;

    assert(cur_image_ptr->flag_1 == 1);
    assert(cur_image_ptr->serial == cur_entry.serial_num);
    assert(cur_image_ptr->size + sizeof(image_header) == cur_entry.size);

    // entry_size 和 offset 是能对应的
    // image 的 size 一定是物理大小

    switch (cur_image_ptr->image_format) {
      case grayscale_4: {
        // 物理大小 assert
        assert(cur_image_ptr->size == cur_image_ptr->sprite_width * cur_image_ptr->height);

        unsigned char *arr[1] = {(void *)cur_image_ptr + sizeof(image_header)};
        NSBitmapImageRep *offscreenRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:arr
                                                                                 pixelsWide:cur_image_ptr->sprite_width
                                                                                 pixelsHigh:cur_image_ptr->height
                                                                              bitsPerSample:8
                                                                            samplesPerPixel:1
                                                                                   hasAlpha:NO
                                                                                   isPlanar:NO
                                                                             colorSpaceName:NSDeviceWhiteColorSpace
                                                                                bytesPerRow:cur_image_ptr->sprite_width
                                                                               bitsPerPixel:8];

        NSData *data = [offscreenRep representationUsingType:NSBitmapImageFileTypePNG properties: @{}];
        [data writeToFile:[NSString stringWithFormat:@"/Users/bunnywong/Desktop/tmp/grayscale_4/%08x.png", cur_image_ptr->serial] atomically:NO];
      } break;
      case grayscale_8: {
        assert(cur_image_ptr->size == cur_image_ptr->sprite_width * cur_image_ptr->height);

        unsigned char *arr[1] = {(void *)cur_image_ptr + sizeof(image_header)};
        NSBitmapImageRep *offscreenRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:arr
                                                                                 pixelsWide:cur_image_ptr->width
                                                                                 pixelsHigh:cur_image_ptr->height
                                                                              bitsPerSample:8
                                                                            samplesPerPixel:1
                                                                                   hasAlpha:NO
                                                                                   isPlanar:NO
                                                                             colorSpaceName:NSDeviceWhiteColorSpace
                                                                                bytesPerRow:cur_image_ptr->width
                                                                               bitsPerPixel:8];

        NSData *data = [offscreenRep representationUsingType:NSBitmapImageFileTypePNG properties: @{}];
        [data writeToFile:[NSString stringWithFormat:@"/Users/bunnywong/Desktop/tmp/grayscale_8/%08x.png", cur_image_ptr->serial] atomically:NO];
      } break;
      case rgb_16: {
        assert(cur_image_ptr->size == cur_image_ptr->sprite_width * cur_image_ptr->height);
        assert(cur_image_ptr->width <= cur_image_ptr->sprite_width);

        // RRRRRGGG:GGGBBBBB -> R8 G8 B8
        int pixelCount = cur_image_ptr->size;

        int16_t* rawPixels = (void *)cur_image_ptr + sizeof(image_header);

        // Preprocess
        unsigned char pixelBuffer[cur_image_ptr->size * 3];
        for (int i = 0; i < pixelCount; i++) {
          pixelBuffer[i * 3 + 0] = ((rawPixels[i] & 0b1111100000000000) >> 11) / (double)0b00011111 * 0b11111111; // R
          pixelBuffer[i * 3 + 1] = ((rawPixels[i] & 0b0000011111100000) >> 5)  / (double)0b00111111 * 0b11111111; // G
          pixelBuffer[i * 3 + 2] = (rawPixels[i] & 0b0000000000011111)         / (double)0b00011111 * 0b11111111; // B
        }

        unsigned char *arr[1] = {pixelBuffer};
        NSBitmapImageRep *offscreenRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:arr
                                                                                 pixelsWide:cur_image_ptr->width
                                                                                 pixelsHigh:cur_image_ptr->height
                                                                              bitsPerSample:8
                                                                            samplesPerPixel:3
                                                                                   hasAlpha:NO
                                                                                   isPlanar:NO
                                                                             colorSpaceName:NSDeviceRGBColorSpace
                                                                                bytesPerRow:cur_image_ptr->width * 3
                                                                               bitsPerPixel:24];

        NSData *data = [offscreenRep representationUsingType:NSBitmapImageFileTypePNG properties: @{}];
        [data writeToFile:[NSString stringWithFormat:@"/Users/bunnywong/Desktop/tmp/rgb_16/%08x.png", cur_image_ptr->serial] atomically:NO];
      } break;
      case argb_32: {
        assert(cur_image_ptr->size == cur_image_ptr->sprite_width * cur_image_ptr->height);
        assert(cur_image_ptr->width <= cur_image_ptr->sprite_width);

        // B G R A -> R G B A
        int pixelCount = cur_image_ptr->size;

        unsigned char* rawPixels = (void *)cur_image_ptr + sizeof(image_header);

        // Preprocess
        unsigned char pixelBuffer[cur_image_ptr->size * 4];
        for (int i = 0; i < pixelCount; i++) {
          pixelBuffer[i * 4 + 0] = rawPixels[i * 4 + 2]; // R
          pixelBuffer[i * 4 + 1] = rawPixels[i * 4 + 1]; // G
          pixelBuffer[i * 4 + 2] = rawPixels[i * 4 + 0]; // B
          pixelBuffer[i * 4 + 3] = rawPixels[i * 4 + 3]; // A
        }

        unsigned char *arr[1] = {pixelBuffer};
        NSBitmapImageRep *offscreenRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:arr
                                                                                 pixelsWide:cur_image_ptr->width
                                                                                 pixelsHigh:cur_image_ptr->height
                                                                              bitsPerSample:8
                                                                            samplesPerPixel:4
                                                                                   hasAlpha:YES
                                                                                   isPlanar:NO
                                                                             colorSpaceName:NSDeviceRGBColorSpace
                                                                                bytesPerRow:cur_image_ptr->width * 4
                                                                               bitsPerPixel:32];

        NSData *data = [offscreenRep representationUsingType:NSBitmapImageFileTypePNG properties: @{}];
        [data writeToFile:[NSString stringWithFormat:@"/Users/bunnywong/Desktop/tmp/argb_32/%08x.png", cur_image_ptr->serial] atomically:NO];
      } break;
      case paletted_8: {
        assert(cur_image_ptr->width <= cur_image_ptr->sprite_width);

        int32_t paletteCount = *(int32_t *)((void *)cur_image_ptr + sizeof(image_header));
        assert(cur_image_ptr->size == cur_image_ptr->sprite_width * cur_image_ptr->height + paletteCount * 4 + sizeof(int32_t));

        // A R G B -> R G B A
        int pixelCount = cur_image_ptr->sprite_width * cur_image_ptr->height;

        unsigned char* palette_ptr = (void *)cur_image_ptr + sizeof(image_header) + sizeof(int32_t);

        // 读入 palette
        unsigned char palettes[paletteCount][4];
        for (int i = 0; i < paletteCount; i++) {
          palettes[i][0] = palette_ptr[i * 4 + 2]; // R
          palettes[i][1] = palette_ptr[i * 4 + 1]; // G
          palettes[i][2] = palette_ptr[i * 4 + 0]; // B
          palettes[i][3] = palette_ptr[i * 4 + 3]; // A
        }

        unsigned char* pixel_ptr = (void *)cur_image_ptr + sizeof(image_header) + sizeof(int32_t) + paletteCount * 4;

        // Preprocess
        unsigned char pixelBuffer[pixelCount * 4];
        for (int i = 0; i < pixelCount; i++) {
          memcpy(&pixelBuffer[i * 4], palettes[pixel_ptr[i]], 4);
        }

        unsigned char *arr[1] = {pixelBuffer};
        NSBitmapImageRep *offscreenRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:arr
                                                                                 pixelsWide:cur_image_ptr->sprite_width
                                                                                 pixelsHigh:cur_image_ptr->height
                                                                              bitsPerSample:8
                                                                            samplesPerPixel:4
                                                                                   hasAlpha:YES
                                                                                   isPlanar:NO
                                                                             colorSpaceName:NSDeviceRGBColorSpace
                                                                                bytesPerRow:cur_image_ptr->sprite_width * 4
                                                                               bitsPerPixel:32];

        NSData *data = [offscreenRep representationUsingType:NSBitmapImageFileTypePNG properties: @{}];
        [data writeToFile:[NSString stringWithFormat:@"/Users/bunnywong/Desktop/tmp/paletted_8/%08x.png", cur_image_ptr->serial] atomically:NO];
      } break;
      case paletted_16: {
        assert(cur_image_ptr->width <= cur_image_ptr->sprite_width);

        int32_t paletteCount = *(int32_t *)((void *)cur_image_ptr + sizeof(image_header));
        assert(cur_image_ptr->size == cur_image_ptr->sprite_width * cur_image_ptr->height + paletteCount * 4 + sizeof(int32_t));

        // A R G B -> R G B A
        int pixelCount = cur_image_ptr->width * cur_image_ptr->height;

        unsigned char* palette_ptr = (void *)cur_image_ptr + sizeof(image_header) + sizeof(int32_t);

        // 读入 palette
        unsigned char palettes[paletteCount][4];
        for (int i = 0; i < paletteCount; i++) {
          palettes[i][0] = palette_ptr[i * 4 + 2]; // R
          palettes[i][1] = palette_ptr[i * 4 + 1]; // G
          palettes[i][2] = palette_ptr[i * 4 + 0]; // B
          palettes[i][3] = palette_ptr[i * 4 + 3]; // A
        }

        int16_t* pixel_ptr = (void *)cur_image_ptr + sizeof(image_header) + sizeof(int32_t) + paletteCount * 4;

        // Preprocess
        unsigned char pixelBuffer[pixelCount * 4];
        for (int i = 0; i < pixelCount; i++) {
          memcpy(&pixelBuffer[i * 4], palettes[pixel_ptr[i]], 4);
        }

        unsigned char *arr[1] = {pixelBuffer};
        NSBitmapImageRep *offscreenRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:arr
                                                                                 pixelsWide:cur_image_ptr->width
                                                                                 pixelsHigh:cur_image_ptr->height
                                                                              bitsPerSample:8
                                                                            samplesPerPixel:4
                                                                                   hasAlpha:YES
                                                                                   isPlanar:NO
                                                                             colorSpaceName:NSDeviceRGBColorSpace
                                                                                bytesPerRow:cur_image_ptr->width * 4
                                                                               bitsPerPixel:32];

        NSData *data = [offscreenRep representationUsingType:NSBitmapImageFileTypePNG properties: @{}];
        [data writeToFile:[NSString stringWithFormat:@"/Users/bunnywong/Desktop/tmp/paletted_16/%08x.png", cur_image_ptr->serial] atomically:NO];
    } break;
      default:
        assert(0);
    }
  }
}

@end


//        NSGraphicsContext* nsContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:offscreenRep];
//        [NSGraphicsContext saveGraphicsState];
//        [NSGraphicsContext setCurrentContext:nsContext];
//
//        // Do the drawing using NSGraphics
//
//        // Do the drawing using Core Graphics
//        CGContextRef cgContext = [nsContext graphicsPort];
//
//        NSGraphicsContext restoreGraphicsState];

//        NSImage* image = [[NSImage alloc] initWithSize:CGSizeMake(cur_image_ptr->width, cur_image_ptr->height)];
//        [image addRepresentation:offscreenRep];
//        NSLog(@"%@", image);
