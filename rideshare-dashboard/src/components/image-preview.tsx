// ImagePreview: Lightbox component for proof/license images
// T024: Opens proof images in modal/dialog overlay

import { useState } from "react"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { cn } from "@/lib/utils"
import { X, ZoomIn, FileImage, AlertCircle } from "lucide-react"

interface ImagePreviewProps {
  imageUrl: string | undefined
  alt?: string
  className?: string
  thumbnailClassName?: string
}

export function ImagePreview({
  imageUrl,
  alt = "Image preview",
  className,
  thumbnailClassName,
}: ImagePreviewProps) {
  const [open, setOpen] = useState(false)
  const [error, setError] = useState(false)

  const handleImageError = () => {
    setError(true)
  }

  // Check if it's a PDF
  const isPdf = imageUrl?.toLowerCase().endsWith(".pdf")

  if (!imageUrl) {
    return (
      <div
        className={cn(
          "flex h-16 w-16 items-center justify-center rounded-md bg-muted text-muted-foreground",
          thumbnailClassName
        )}
      >
        <FileImage className="h-6 w-6" />
      </div>
    )
  }

  if (error) {
    return (
      <div
        className={cn(
          "flex h-16 w-16 items-center justify-center rounded-md bg-red-50 text-red-500",
          thumbnailClassName
        )}
        title="Failed to load image"
      >
        <AlertCircle className="h-6 w-6" />
      </div>
    )
  }

  return (
    <>
      {/* Thumbnail */}
      <button
        onClick={() => setOpen(true)}
        className={cn(
          "relative overflow-hidden rounded-md transition-opacity hover:opacity-80",
          thumbnailClassName
        )}
      >
        {isPdf ? (
          <div className="flex h-full w-full items-center justify-center bg-red-50 text-red-600">
            <span className="text-xs font-medium">PDF</span>
          </div>
        ) : (
          <>
            <img
              src={imageUrl}
              alt={alt}
              className="h-full w-full object-cover"
              onError={handleImageError}
            />
            <div className="absolute inset-0 flex items-center justify-center bg-black/0 opacity-0 transition-all hover:bg-black/20 hover:opacity-100">
              <ZoomIn className="h-6 w-6 text-white" />
            </div>
          </>
        )}
      </button>

      {/* Full-size Modal */}
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className={cn("max-w-4xl", className)}>
          <DialogHeader>
            <DialogTitle className="flex items-center justify-between">
              <span>Image Preview</span>
              <Button
                variant="ghost"
                size="icon"
                onClick={() => setOpen(false)}
              >
                <X className="h-4 w-4" />
              </Button>
            </DialogTitle>
          </DialogHeader>
          <div className="flex items-center justify-center p-4">
            {isPdf ? (
              <div className="text-center">
                <p className="mb-4 text-muted-foreground">
                  This file is a PDF document
                </p>
                <Button asChild>
                  <a
                    href={imageUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    Open PDF
                  </a>
                </Button>
              </div>
            ) : (
              <img
                src={imageUrl}
                alt={alt}
                className="max-h-[70vh] max-w-full rounded-lg object-contain"
                onError={handleImageError}
              />
            )}
          </div>
        </DialogContent>
      </Dialog>
    </>
  )
}

export default ImagePreview
